import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';

enum FriendCardType {
  request,
  sentRequest,
  currentFriend,
  addFriend,
}

class FriendCard extends StatefulWidget {
  const FriendCard(
      {super.key,
      required this.type,
      required this.name,
      required this.uid,
      required this.onPressed});

  final FriendCardType type;
  final String name;
  final String uid;
  final Function onPressed;

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> {
  String? _profileImage;
  String? _currentName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _profileImage = userData?['profile_image'];
          _currentName = userData?['name'] ?? widget.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _currentName = widget.name;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProvider>(context, listen: false);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox(
            width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
            height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
            child: CircleAvatar(
              radius: min(SizeConfig.blockSizeHorizontal! * 5, 37.5),
              backgroundColor: Colors.grey[300],
              backgroundImage: _profileImage != null
                  ? CachedNetworkImageProvider(
                      _profileImage!,
                      maxHeight: 100,
                      maxWidth: 100,
                    )
                  : null,
              child: _profileImage == null
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal! * 2),
          Expanded(
            child: _isLoading
                ? const Text('Loading...', style: TextStyle(fontSize: 20))
                : Text(_currentName ?? widget.name, style: const TextStyle(fontSize: 20)),
          ),

          if (widget.type == FriendCardType.request)
            SizedBox(
              width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
              height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
              child: ElevatedButton(
                  onPressed: () {
                    // determine database path depending on type
                    String path = (widget.type == FriendCardType.request)
                        ? 'friend_requests'
                        : 'friends';

                    // remove friend request or friend at users/{uid}/friend_requests/uid or users/{uid}/friends/uid
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(Auth().user!.uid)
                        .update({
                      '$path.${widget.uid}': FieldValue.delete(),
                    }).catchError((error) {
                      print('Failed to delete friend request: $error');
                    }).then((value) {
                      Database().blockUser(widget.uid).then((value) {
                        widget.onPressed();
                      });
                    });
                  },
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    backgroundColor: WidgetStateProperty.all(Colors.orange),
                    shape: WidgetStateProperty.all(const CircleBorder()),
                  ),
                  child: const Icon(Icons.block, color: Colors.white)),
            ),

          SizedBox(width: SizeConfig.blockSizeHorizontal! * 2),

          // ternary expression
          // (expression) ? (if true) : (if false)
          (widget.type != FriendCardType.addFriend)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // determine database path depending on type
                        String path = (widget.type == FriendCardType.request)
                            ? 'friend_requests'
                            : (widget.type == FriendCardType.sentRequest)
                                ? 'outgoing_requests'
                                : 'friends';

                        // For sent requests, also remove from the receiver's friend_requests
                        if (widget.type == FriendCardType.sentRequest) {
                          // Remove from receiver's friend_requests
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.uid)
                              .update({
                            'friend_requests.${Auth().user!.uid}': FieldValue.delete(),
                          }).catchError((error) {
                            print('Failed to delete friend request from receiver: $error');
                          });

                          // Remove from sender's outgoing_requests
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(Auth().user!.uid)
                              .update({
                            'outgoing_requests.${widget.uid}': FieldValue.delete(),
                          }).catchError((error) {
                            print('Failed to delete outgoing request: $error');
                          }).then((value) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Friend request unsent'),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            widget.onPressed();
                          });
                        } else {
                          // remove friend request or friend at users/{uid}/friend_requests/uid or users/{uid}/friends/uid
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(Auth().user!.uid)
                              .update({
                            '$path.${widget.uid}': FieldValue.delete(),
                          }).catchError((error) {
                            print('Failed to delete friend request: $error');
                          }).then((value) {
                            widget.onPressed();
                          });
                        }
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.red),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.cancel, color: Colors.white)),
                )
              : Container(),
          (widget.type == FriendCardType.addFriend)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // Check if trying to send friend request to yourself
                        if (widget.uid == Auth().user!.uid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You cannot send a friend request to yourself'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // add friend request at users/{uid}/friend_requests/$uid
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid)
                            .update({
                          'outgoing_requests.${widget.uid}': {'name': _currentName ?? widget.name},
                        }).catchError((error) {
                          print('Failed to add friend request: $error');
                        }).then((value) {
                          // write request on receiver's side
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.uid)
                              .update({
                            'friend_requests.${Auth().user!.uid}': {
                              'name': provider.userData?['name'] ?? ''
                            },
                          }).catchError((error) {
                            print('Failed to add outgoing request: $error');
                          }).then((value) {
                            widget.onPressed();
                          });
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.blue),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.person_add, color: Colors.white)),
                )
              : Container(),
          (widget.type == FriendCardType.request)
              ? SizedBox(width: SizeConfig.blockSizeHorizontal! * 2)
              : Container(),
          (widget.type == FriendCardType.request)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // add friend of value uid at users/{uid}/friends/$uid and delete request at users/{uid}/friend_requests/$uid
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid)
                            .update({
                          'friends.${widget.uid}': {'name': _currentName ?? widget.name},
                          'friend_requests.${widget.uid}': FieldValue.delete(),
                        }).catchError((error) {
                          print('Failed to add friend: $error');
                        }).then((value) {
                          // add user as friend of value Auth().user!.uid at users/$uid/friends/Auth().user!.uid
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.uid)
                              .update({
                            'friends.${Auth().user!.uid}': {
                              'name': provider.userData?['name'] ?? ''
                            },
                            'outgoing_requests.${Auth().user!.uid}':
                                FieldValue.delete(),
                          }).catchError((error) {
                            print('Failed to add friend: $error');
                          }).then((value) {
                            widget.onPressed();
                          });
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child:
                          const Icon(Icons.check_circle, color: Colors.white)),
                )
              : Container(),
        ],
      ),
    ));
  }
}
