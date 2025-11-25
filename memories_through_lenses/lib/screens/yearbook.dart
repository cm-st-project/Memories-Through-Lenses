import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/small_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class YearbookScreen extends StatefulWidget {
  const YearbookScreen({super.key});

  @override
  State<YearbookScreen> createState() => _YearbookScreenState();
}

class _YearbookScreenState extends State<YearbookScreen> {
  List<DropdownMenuItem> years = [];
  String selectedYear = '2025';
  List<PostData> posts = [];

  @override
  void initState() {
    super.initState();
    getPosts();

    setState(() {
      years = getYears();
      selectedYear = DateTime.now().year.toString();
    });
  }

  List<DropdownMenuItem> getYears() {
    List<DropdownMenuItem> items = [];
    int currentYear = DateTime.now().year;
    for (int i = 2024; i <= currentYear; i++) {
      items.add(DropdownMenuItem(
        value: i.toString(),
        child: Text(i.toString()),
      ));
    }
    return items;
  }

  void _showDeleteDialog(String postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove from Yearbook'),
          content: const Text(
              'Are you sure you want to remove this image from your yearbook?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Database().removeFromYearbook(postId);
                setState(() {
                  posts.removeWhere((post) => post.id == postId);
                });
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                        content: Text('Image removed from yearbook')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> getPosts() async {
    try {
      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      List<dynamic> yearbookList = userData['yearbook'] ?? [];
      List<dynamic> blockedUsers = userData['blocked'] ?? [];
      List<dynamic> groups = userData['groups'] ?? [];

      List<PostData> temp = [];
      String currentUserId = Auth().user?.uid ?? '';

      for (var postID in yearbookList) {
        Map<String, dynamic>? post = await Database().getPost(postID);
        if (post == null ||
            blockedUsers.contains(post['user_id']) ||
            !groups.contains(post['group_id'])) {
          continue;
        }

        // check if the created_at date is in the selected year
        DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
            post['created_at'].seconds * 1000);
        if (createdAt.year.toString() != selectedYear) {
          continue;
        }

        // Check if user has liked or disliked this post
        String userOpinion = "none";
        if (post['likes']?.contains(currentUserId) ?? false) {
          userOpinion = "like";
        } else if (post['dislikes']?.contains(currentUserId) ?? false) {
          userOpinion = "dislike";
        }

        temp.add(PostData(
          id: post['id'],
          creator: post['user_id'],
          mediaURL: post['image_url'],
          mediaType: 'image',
          caption: post['caption'],
          likes: post['likes'].length,
          dislikes: post['dislikes'].length,
          created_at: DateTime.fromMillisecondsSinceEpoch(
              post['created_at'].seconds * 1000),
          userOpinion: userOpinion,
        ));
      }
      temp = temp
          .where((element) => element.created_at.year.toString() == selectedYear)
          .toList();

      if (mounted) {
        setState(() {
          posts = temp;
        });
      }
    } catch (e) {
      print('Error loading yearbook posts: $e');
    }
  }

  // void getPosts() {
  //   // get list of all groups a user is part of from their userData
  //   List<dynamic> groups = singleton.userData['groups'];
  //
  //   print(singleton.userData['name']);
  //
  //   for (var id in groups) {
  //     Database().getPosts(id.toString(), 'newest').then((value) {
  //       List<PostData> temp = [];
  //       List<dynamic> blockedUsers = (singleton.userData['blocked'] != null)
  //           ? singleton.userData['blocked']
  //           : [];
  //       List<dynamic> blockedPosts =
  //           (singleton.userData['reported_posts'] != null)
  //               ? singleton.userData['reported_posts']
  //               : [];
  //       // print("VALUE: $value");
  //       for (var element in value) {
  //         if (blockedUsers.contains(element['user_id']) ||
  //             blockedPosts.contains(element['id'])) {
  //           continue;
  //         }
  //
  //         // check if the created_at date is in the selected year
  //         DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
  //             element['created_at'].seconds * 1000);
  //         if (createdAt.year.toString() != selectedYear) {
  //           print(
  //               "Skipping post with id ${element['id']} because it is not in the selected year");
  //           print("Selected year: $selectedYear");
  //           print("Post year: ${createdAt.year}");
  //           continue;
  //         }
  //
  //         temp.add(PostData(
  //           id: element['id'],
  //           creator: element['user_id'],
  //           mediaURL: element['image_url'],
  //           mediaType: 'image',
  //           caption: element['caption'],
  //           likes: element['likes'].length,
  //           dislikes: element['dislikes'].length,
  //           // Timestamp to datetime
  //           created_at: DateTime.fromMillisecondsSinceEpoch(
  //               element['created_at'].seconds * 1000),
  //         ));
  //       }
  //
  //       // sort by created_at so that the newest post is at the top
  //       temp = temp
  //           .where(
  //               (element) => element.created_at.year.toString() == selectedYear)
  //           .toList();
  //
  //       setState(() {
  //         posts = temp;
  //       });
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DropdownButton(
            itemHeight: 75,
            style: GoogleFonts.merriweather(fontSize: 50, color: Colors.black),
            value: selectedYear,
            items: years,
            onChanged: (value) {
              setState(() {
                print("Selected year: $value");
                selectedYear = value;
                getPosts();
              });
            }),
      )),
      body: posts.isEmpty
          ? Column(
              children: [
                SizedBox(height: SizeConfig.blockSizeVertical! * 10),
                Center(
                    child: Icon(Icons.photo_album_outlined,
                        size: 100, color: Colors.blueAccent)),
                SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                Center(
                  child: Text('Your yearbook has no posts yet.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.merriweather(fontSize: 25)),
                ),
              ],
            )
          : Center(
            child: Column(
              children: [
                Expanded(
                  flex: 15,
                  child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                              childAspectRatio: 0.7),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onLongPress: () => _showDeleteDialog(posts[index].id),
                          child: SmallPostCard(
                            id: posts[index].id,
                            creator: posts[index].creator,
                            mediaURL: posts[index].mediaURL,
                            mediaType: posts[index].mediaType,
                            caption: posts[index].caption,
                            likes: posts[index].likes,
                            dislikes: posts[index].dislikes,
                            created_at: posts[index].created_at,
                          ),
                        );
                      }),
                ),
                Expanded(
                  child: Text('Long press an image to remove it from your yearbook.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.merriweather(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
    );
  }
}
