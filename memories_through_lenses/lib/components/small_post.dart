import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:memories_through_lenses/screens/comments.dart';
import 'package:google_fonts/google_fonts.dart';

// ignore: must_be_immutable
class SmallPostCard extends StatefulWidget {
  SmallPostCard({
    super.key,
    required this.id,
    required this.mediaURL,
    required this.mediaType,
    required this.caption,
    required this.creator,
    required this.created_at,
    this.likes = 0,
    this.dislikes = 0,
  });
  final String id;
  final String mediaURL;
  final String mediaType;
  final String creator;
  int likes = 0;
  int dislikes = 0;
  final String caption;
  final DateTime created_at;

  @override
  State<SmallPostCard> createState() => _SmallPostCardState();
}

class _SmallPostCardState extends State<SmallPostCard> {
  String formatDate(DateTime date) {
    return "${date.month}/${date.day}";
  }

  @override
  Widget build(BuildContext context) {
    late VideoPlayerController _controller;
    if (widget.mediaType == "video") {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(
            formatDate(widget.created_at),
            style: GoogleFonts.merriweather(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          SizedBox(
            width: SizeConfig.blockSizeHorizontal! * 40,
            height: SizeConfig.blockSizeHorizontal! * 40,
            child: Card(
              color: Colors.blue,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    // ternary expression:
                    // (condition) ? (if true) : (if false)
                    child: (widget.mediaType == "image")
                        ? InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommentScreen(
                                    id: widget.id,
                                    mediaURL: widget.mediaURL,
                                    mediaType: widget.mediaType,
                                    creator: widget.creator,
                                  ),
                                ),
                              );
                            },
                            child: CachedNetworkImage(
                              imageUrl: widget.mediaURL,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Center(child: Icon(Icons.error)),
                            ),
                          )
                        : FutureBuilder(
                            future: _controller.initialize(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return VideoPlayer(_controller);
                              } else {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                            },
                          ),
                  ),
                  // report button on the top right corner
                  if (widget.creator != Auth().user?.uid)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          SizeConfig.blockSizeHorizontal! * 76, 8, 8, 8),
                      child: SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(132, 158, 158, 158),
                              padding: const EdgeInsets.all(0.0)),
                          child: const Icon(
                            Icons.report,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return ReportPostPopup(
                                  postId: widget.id,
                                  postCreator: widget.creator,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 40,
                    // height: SizeConfig.blockSizeHorizontal! * 10,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                        widget.caption,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,

    )
                        ),
                      ),
                      // child: Text(
                      //   widget.caption,
                      //   textAlign: TextAlign.center,
                      // ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// report post popup
class ReportPostPopup extends StatefulWidget {
  const ReportPostPopup(
      {super.key, required this.postId, required this.postCreator});
  final String postId;
  final String postCreator;

  @override
  State<ReportPostPopup> createState() => _ReportPostPopupState();
}

class _ReportPostPopupState extends State<ReportPostPopup> {
  bool isReporting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Report Post"),
      content: isReporting
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Processing..."),
              ],
            )
          : const Text("Are you sure you want to report this post?"),
      actions: isReporting
          ? []
          : [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  setState(() {
                    isReporting = true;
                  });

                  try {
                    await Database().reportPost(widget.postId, widget.postCreator);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post reported successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() {
                        isReporting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error reporting post: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Report"),
              ),
              TextButton(
                onPressed: () async {
                  setState(() {
                    isReporting = true;
                  });

                  try {
                    await Database().reportAndBlockUser(widget.postId, widget.postCreator);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User blocked and post reported successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() {
                        isReporting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error blocking user: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Block User"),
              )
            ],
    );
  }
}
