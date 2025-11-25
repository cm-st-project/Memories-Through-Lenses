import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';

class Comment extends StatefulWidget {
  const Comment(
      {super.key,
      required this.description,
      required this.profilePic,
      required this.username,
      required this.date,
      required this.likes,
      required this.postId,
      required this.commentId});
  final String profilePic;
  final String description;
  final String username;
  final String date;
  final List<dynamic> likes;
  final String postId;
  final String commentId;

  @override
  State<Comment> createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  bool isLiked = false;
  late List<dynamic> currentLikes;
  
  @override
  void initState() {
    super.initState();
    currentLikes = List.from(widget.likes);
    checkIfLiked();
  }
  
  void checkIfLiked() {
    final currentUser = Auth().user?.uid;
    if (currentUser != null) {
      setState(() {
        isLiked = currentLikes.contains(currentUser);
      });
    }
  }
  
  void toggleLike() async {
    final currentUser = Auth().user?.uid;
    if (currentUser == null) return;
    
    setState(() {
      if (isLiked) {
        // Unlike
        currentLikes.remove(currentUser);
        Database().removeLikeComment(widget.postId, widget.commentId);
      } else {
        // Like
        currentLikes.add(currentUser);
        Database().likeComment(widget.postId, widget.commentId);
      }
      isLiked = !isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        // TODO: REPLACE WITH ONLONGPRESS WHEN MOVING TO TEST ON DEVICES
        print("Long Pressed");
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const ReportCommentPopup();
          },
        );
      },
      child: Container(
        height: SizeConfig.blockSizeVertical! * 10,
        color: Colors.white,
        child: Padding(
          // EdgeInsets.all(8.0)
          padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              widget.profilePic == ""
                  ? const CircleAvatar(
                      radius: 20,
                      backgroundImage: AssetImage("assets/generic_profile.png"),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundImage: CachedNetworkImageProvider(
                        widget.profilePic,
                        maxHeight: 100,
                        maxWidth: 100,
                      ),
                    ),
              Container(
                color: Colors.white,
                width: SizeConfig.blockSizeHorizontal! * 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.username),
                        Padding(padding: EdgeInsets.all(5.0)),
                        Text(widget.date, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Text(widget.description),
                    // TextButton(
                    //   style: TextButton.styleFrom(
                    //       padding: EdgeInsets.zero),
                    //   onPressed: () {},
                    //   child: Text("Reply"),
                    // ),
                    // TextButton(
                    //   style: TextButton.styleFrom(
                    //       padding: EdgeInsets.zero),
                    //   onPressed: () {},
                    //   child: Text("View Replies"),
                    // )
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: toggleLike,
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                    ),
                  ),
                  Text(currentLikes.length.toString()),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// report popup
class ReportCommentPopup extends StatelessWidget {
  const ReportCommentPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Comment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Text('Are you sure you want to report this comment?'),
          TextField(
            decoration: InputDecoration(
              hintText: 'Reason for reporting',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Report'),
        ),
      ],
    );
  }
}
