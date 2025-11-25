import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/auth.dart';

class Database {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Auth _auth = Auth();
  final UserProvider? _userProvider;

  Database([this._userProvider]);

  Future<List<Map<String, dynamic>>> getSchools() async {
    var schools = await _firestore.collection('schools').get();
    List<Map<String, dynamic>> result =
        schools.docs.map((e) => e.data()).toList();

    // add the id to each school
    for (var i = 0; i < result.length; i++) {
      result[i]['id'] = schools.docs[i].id;
    }

    return result;
  }

  Future<String> createGroup(
      String name, String description, bool private) async {
    var ref = _firestore.collection('groups').doc();
    await ref.set({
      'name': name,
      'description': description,
      'private': private,
      'members': [_auth.user!.uid],
      'member_count': 1,
      'owner': _auth.user!.uid,
      'join_requests': [],
      'school': 'bkuv1JQ2R3HSkfs2Aotg',
    });

    await _firestore.collection('users').doc(_auth.user!.uid).update({
      'groups': FieldValue.arrayUnion([ref.id])
    });

    return ref.id;
  }

  Future<void> updateGroup(
      String id, String name, String description, bool isPrivate) async {
    _firestore.collection('groups').doc(id).update(
        {'name': name, 'description': description, 'private': isPrivate});
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      // Get the group data first to find all members and invites
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        print('Group does not exist');
        return;
      }

      final groupData = groupDoc.data();
      final List<dynamic> members = groupData?['members'] ?? [];
      final List<dynamic> joinRequests = groupData?['join_requests'] ?? [];

      // Remove group from all members' groups array
      for (String memberId in members) {
        await _firestore.collection('users').doc(memberId).update({
          'groups': FieldValue.arrayRemove([groupId])
        });
      }

      // Remove group invites from users who were invited
      final usersSnapshot = await _firestore
          .collection('users')
          .where('group_invites.$groupId', isNull: false)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        await _firestore
            .collection('users')
            .doc(userDoc.id)
            .update({'group_invites.$groupId': FieldValue.delete()});
      }

      // Remove group from users who sent join requests
      for (String userId in joinRequests) {
        await _firestore.collection('users').doc(userId).update({
          'group_requests': FieldValue.arrayRemove([groupId])
        });
      }

      // Delete all posts in this group
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('group_id', isEqualTo: groupId)
          .get();

      for (var postDoc in postsSnapshot.docs) {
        // Delete all comments in each post
        final commentsSnapshot = await _firestore
            .collection('posts')
            .doc(postDoc.id)
            .collection('comments')
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          await commentDoc.reference.delete();
        }

        // Delete the post
        await postDoc.reference.delete();
      }

      // Finally, delete the group document
      await _firestore.collection('groups').doc(groupId).delete();

      print('Group deleted successfully');
    } catch (e) {
      print('Error deleting group: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup() async {}

  Future<String> uploadProfileImage(File image) async {
    var ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${_auth.user!.uid}');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateProfile(String username, String? profileImage) async {
    if (profileImage != null) {
      _firestore.collection('users').doc(_auth.user!.uid).update({
        'name': username,
        'profile_image': profileImage,
      });

      _auth.user!.updatePhotoURL(profileImage);
    } else {
      _firestore.collection('users').doc(_auth.user!.uid).update({
        'name': username,
      });
    }
  }

  Future<bool> createPost(String groupId, String caption, File image) async {
    var currentTime = DateTime.now();
    var ref = FirebaseStorage.instance
        .ref()
        .child('posts/${_auth.user!.uid}/$currentTime');
    await ref.putFile(image);
    var imageUrl = await ref.getDownloadURL();

    Map<String, String> validationData = {
      'url': imageUrl,
      'user_uid': _auth.user!.uid,
      'image_name': '$currentTime',
    };

    // get the server url from RTDB at node moderation_server_url
    var url = await FirebaseDatabase.instance
        .ref('moderation_server_url')
        .once()
        .then((value) => value.snapshot.value.toString());
    print('Server URL: $url');
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(validationData),
    );

    if (response.statusCode == 200) {
      print('Image processed successfully');

      var message = jsonDecode(response.body);
      if (message['offensive'] == true) {
        return false;
      }
    } else {
      print('Failed to process image: ${response.body}');
      return false;
    }

    DocumentReference postRef = await _firestore.collection('posts').add({
      'group_id': groupId,
      'user_id': _auth.user!.uid,
      'caption': caption,
      'image_url': imageUrl,
      'likes': [],
      'dislikes': [],
      'comments': [],
      'created_at': DateTime.now()
    });

    url = await FirebaseDatabase.instance
        .ref('yearbook_server_url')
        .once()
        .then((value) => value.snapshot.value.toString());

    var data = {
      'photo_path': imageUrl,
      'post_id': postRef.id,
    };
    final response_yearbook = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response_yearbook.statusCode == 200) {
      print(response.body);
    } else {
      print('Failed to process image: ${response.body}');
    }
    return true;
  }

  Future<void> likePost(String postId) async {
    var post = await _firestore.collection('posts').doc(postId).get();
    var likes = post.data()!['likes'];
    var dislikes = post.data()!['dislikes'];

    // If user already liked, remove the like (toggle off)
    if (likes.contains(_auth.user!.uid)) {
      await removeLikePost(postId);
      return;
    }

    // If user previously disliked, remove the dislike
    if (dislikes.contains(_auth.user!.uid)) {
      await removeDislikePost(postId);
    }

    // Add the like
    await _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeLikePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<void> dislikePost(String postId) async {
    var post = await _firestore.collection('posts').doc(postId).get();
    var likes = post.data()!['likes'];
    var dislikes = post.data()!['dislikes'];

    // If user already disliked, remove the dislike (toggle off)
    if (dislikes.contains(_auth.user!.uid)) {
      await removeDislikePost(postId);
      return;
    }

    // If user previously liked, remove the like
    if (likes.contains(_auth.user!.uid)) {
      await removeLikePost(postId);
    }

    // Add the dislike
    await _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeDislikePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<List<Map<String, dynamic>>> getPosts(
      String groupId, String mode) async {
    var posts = await _firestore
        .collection('posts')
        .where('group_id', isEqualTo: groupId)
        .get();

    var posts_list = posts.docs.map((e) => e.data()).toList();

    // for each post, add the id
    for (var i = 0; i < posts_list.length; i++) {
      // print("Attempting to add id to post");
      posts_list[i]['id'] = posts.docs[i].id;
      // print("Added id to post: {${posts_list[i]['id']}");
    }

    if (mode == 'newest') {
      //print("Sorting by newest");
      posts_list.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    } else if (mode == 'popular') {
      //print("Sorting by popular");
      posts_list.sort((a, b) => b['likes'].length.compareTo(a['likes'].length));

      // reverse the list to get the most popular first
      posts_list = posts_list.reversed.toList();
    }

    // for debug, print the post id, created_at, and likes
    for (var post in posts_list) {
      print(
          "Post ID: ${post['id']} Created At: ${post['created_at']} Likes: ${post['likes'].length}");
    }

    return posts_list;
  }

  Future<Map<String, dynamic>?> getPost(String postId) async {
    // check if the user previously liked the post
    var post = await _firestore.collection('posts').doc(postId).get();
    if (!post.exists) {
      return null;
    }
    var post_data = post.data();
    post_data!['id'] = postId;
    return post_data;
  }

  Future<List<Map<String, dynamic>>> getYearBook() {
    // get every post in the posts collection whose id is in the yearbook array of the user's data from provider
    return _firestore
        .collection('posts')
        .where(FieldPath.documentId,
            whereIn: _userProvider?.userData?['yearbook'] ?? [])
        .get()
        .then((value) {
      var posts_list = value.docs.map((e) => e.data()).toList();

      // for each post, add the id
      for (var i = 0; i < posts_list.length; i++) {
        posts_list[i]['id'] = value.docs[i].id;
      }

      return posts_list;
    });
  }

  Future<void> reportPost(String postId, String postCreator) async {
    try {
      // Get the post to find the group_id
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final groupId = postDoc.data()?['group_id'] ?? '';

      await _firestore.collection('reports').add({
        'post_id': postId,
        'post_creator': postCreator,
        'group_id': groupId,
        'reporter_id': _auth.user!.uid,
        'created_at': Timestamp.now(),
        'status': 'pending', // pending, approved, rejected
      });

      // record the post in the user's reported posts
      await _firestore.collection('users').doc(_auth.user!.uid).update({
        'reported_posts': FieldValue.arrayUnion([postId])
      });
    } catch (e) {
      print('Error reporting post: $e');
      rethrow;
    }
  }

  // Get reports for groups owned by the current user
  Future<List<Map<String, dynamic>>> getReportsForMyGroups() async {
    try {
      print('Getting reports for my groups...');

      // Get all groups owned by current user
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('owner', isEqualTo: _auth.user!.uid)
          .get();

      List<String> myGroupIds =
          groupsSnapshot.docs.map((doc) => doc.id).toList();
      print('Found ${myGroupIds.length} groups owned by user');

      if (myGroupIds.isEmpty) {
        return [];
      }

      // Get all pending reports for these groups (without orderBy to avoid index requirement)
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('group_id', whereIn: myGroupIds)
          .where('status', isEqualTo: 'pending')
          .get();

      print('Found ${reportsSnapshot.docs.length} pending reports');

      List<Map<String, dynamic>> reports = [];
      for (var doc in reportsSnapshot.docs) {
        Map<String, dynamic> report = doc.data();
        report['id'] = doc.id;

        // Get post details
        final postDoc =
            await _firestore.collection('posts').doc(report['post_id']).get();
        if (postDoc.exists) {
          report['post_data'] = postDoc.data();
        } else {
          print('Post not found for report: ${doc.id}');
        }

        // Get reporter details
        final reporterDoc = await _firestore
            .collection('users')
            .doc(report['reporter_id'])
            .get();
        if (reporterDoc.exists) {
          report['reporter_name'] = reporterDoc.data()?['name'] ?? 'Unknown';
        } else {
          report['reporter_name'] = 'Unknown';
        }

        reports.add(report);
      }

      // Sort by created_at descending (client-side)
      reports.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      print('Returning ${reports.length} reports');
      return reports;
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }

  // Approve report and delete the post
  Future<void> approveReport(String reportId, String postId) async {
    try {
      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'approved',
        'reviewed_at': DateTime.now(),
        'reviewed_by': _auth.user!.uid,
      });

      // Delete the post and its comments
      final commentsSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .get();

      for (var commentDoc in commentsSnapshot.docs) {
        await commentDoc.reference.delete();
      }

      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print('Error approving report: $e');
      rethrow;
    }
  }

  // Reject report and keep the post
  Future<void> rejectReport(String reportId) async {
    try {
      print('Rejecting report: $reportId');

      // Get the report to find the reporter and post
      final reportDoc =
          await _firestore.collection('reports').doc(reportId).get();
      final reportData = reportDoc.data();

      if (reportData != null) {
        final postId = reportData['post_id'];
        print('Post ID: $postId');

        // Get all users who have this post in their reported_posts list
        final usersSnapshot = await _firestore
            .collection('users')
            .where('reported_posts', arrayContains: postId)
            .get();

        print(
            'Found ${usersSnapshot.docs.length} users with this post in reported_posts');

        // Remove post from all these users' reported_posts lists
        for (var userDoc in usersSnapshot.docs) {
          print('Removing post from user: ${userDoc.id}');
          await _firestore.collection('users').doc(userDoc.id).update({
            'reported_posts': FieldValue.arrayRemove([postId])
          });
        }
      }

      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'rejected',
        'reviewed_at': Timestamp.now(),
        'reviewed_by': _auth.user!.uid,
      });

      print('Report rejected successfully');
    } catch (e) {
      print('Error rejecting report: $e');
      rethrow;
    }
  }

  // Get join requests for groups owned by current user
  Future<List<Map<String, dynamic>>> getJoinRequestsForMyGroups() async {
    try {
      final currentUserId = _auth.user?.uid;
      if (currentUserId == null) {
        print('getJoinRequestsForMyGroups: No current user');
        return [];
      }

      print('========== JOIN REQUESTS DEBUG ==========');
      print('Current User ID: $currentUserId');

      // Get all groups owned by current user
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('owner', isEqualTo: currentUserId)
          .get();

      print('Found ${groupsSnapshot.docs.length} groups owned by current user');

      List<Map<String, dynamic>> allRequests = [];

      // For each group, get the join requests
      for (var groupDoc in groupsSnapshot.docs) {
        final groupData = groupDoc.data();
        final joinRequests = groupData['join_requests'] as List<dynamic>? ?? [];

        print('Group: ${groupData['name']} (${groupDoc.id})');
        print('  Join requests: $joinRequests');

        // For each user in join_requests, get their info
        for (var userId in joinRequests) {
          print('  Fetching user data for: $userId');
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            allRequests.add({
              'user_id': userId,
              'user_name': userData?['name'] ?? 'Unknown User',
              'user_email': userData?['email'] ?? '',
              'profile_image': userData?['profile_image'],
              'group_id': groupDoc.id,
              'group_name': groupData['name'] ?? 'Unknown Group',
            });
            print('  Added request from: ${userData?['name']}');
          }
        }
      }

      print('Total join requests found: ${allRequests.length}');
      return allRequests;
    } catch (e) {
      print('Error getting join requests: $e');
      return [];
    }
  }

  // Approve a join request
  Future<void> approveJoinRequest(String userId, String groupId) async {
    try {
      // Add user to group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'join_requests': FieldValue.arrayRemove([userId]),
      });

      // Add group to user's groups
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayUnion([groupId]),
        'group_requests': FieldValue.arrayRemove([groupId]),
      });
    } catch (e) {
      print('Error approving join request: $e');
      rethrow;
    }
  }

  // Reject a join request
  Future<void> rejectJoinRequest(String userId, String groupId) async {
    try {
      // Remove user from group's join_requests
      await _firestore.collection('groups').doc(groupId).update({
        'join_requests': FieldValue.arrayRemove([userId]),
      });

      // Remove group from user's group_requests
      await _firestore.collection('users').doc(userId).update({
        'group_requests': FieldValue.arrayRemove([groupId]),
      });
    } catch (e) {
      print('Error rejecting join request: $e');
      rethrow;
    }
  }

  // create a comment on a post
  Future<void> createComment(String postId, String comment) async {
    // comments is a subcollection of posts
    _firestore.collection('posts').doc(postId).collection('comments').add({
      'uid': _auth.user!.uid,
      'description': comment,
      'date': DateTime.now(),
      'likes': [],
      'username': _userProvider?.userData?['name'] ?? '',
      'profilePic': _auth.user!.photoURL
    });
  }

  // like a comment by adding the user's uid to the likes array
  Future<void> likeComment(String postId, String commentId) async {
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  // unlike a comment
  Future<void> removeLikeComment(String postId, String commentId) async {
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  // report a comment
  Future<void> reportComment(String postId, String commentId) async {
    _firestore.collection('reports').add({
      'post_id': postId,
      'comment_id': commentId,
      'user_id': _auth.user!.uid,
      'created_at': DateTime.now()
    });
  }

  // delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // edit a comment
  Future<void> editComment(
      String postId, String commentId, String newComment) async {
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'description': newComment});
  }

  // get all comments for a post
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    var comments = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .get();

    var comments_list = comments.docs.map((e) => e.data()).toList();

    // for each comment, add the id
    for (var i = 0; i < comments_list.length; i++) {
      comments_list[i]['id'] = comments.docs[i].id;

      // get the user's name and profile image
      // print("Getting user data at ${comments_list[i]['uid']}");
      // var user = await _firestore
      //     .collection('users')
      //     .doc(comments_list[i]['uid'])
      //     .get().then((value) {
      //       var user_data = value.data();
      //       print("User data: ${value.data()}");
      //     });

      // comments_list[i]['username'] = user_data!['name'];
      if (!comments_list[i].containsKey("profilePic") ||
          comments_list[i]['profilePic'] == null ||
          comments_list[i]['profilePic'].isEmpty) {
        comments_list[i]['profilePic'] =
            'https://imageio.forbes.com/specials-images/imageserve/5d35eacaf1176b0008974b54/0x0.jpg?format=jpg&crop=4560,2565,x790,y784,safe&height=900&width=1600&fit=bounds';
      }
    }

    return comments_list;
  }

  Future<void> reportAndBlockUser(String postId, String postCreator) async {
    reportPost(postId, postCreator);
    blockUser(postCreator);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    var users = await _firestore.collection('users').get();
    List<Map<String, dynamic>> result =
        users.docs.map((e) => e.data()).toList();
    // add the uid to each user
    for (var i = 0; i < result.length; i++) {
      result[i]['uid'] = users.docs[i].id;
    }
    return result;
  }

  // block user function that adds the given uid to the current user's blocked list
  Future<void> blockUser(String uid) async {
    _firestore.collection('users').doc(_auth.user!.uid).update({
      'blocked': FieldValue.arrayUnion([uid])
    });
  }

  // Remove a post from the user's yearbook
  Future<void> removeFromYearbook(String postId) async {
    await _firestore.collection('users').doc(_auth.user!.uid).update({
      'yearbook': FieldValue.arrayRemove([postId])
    });
  }
}
