import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:provider/provider.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Widget> combined = [];

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await Database().getUsers().then((value) {
        setState(() {
          if (value.isNotEmpty) {
            users = value;
            searchResults = value; // Show all users when text field is empty
          }
        });
      });
    } else {
      setState(() {
        print("searching for $query");
        searchResults = users
            .where((element) =>
                element['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
        print("search results: $searchResults");
      });
    }
  }

  @override
  void initState() {
    super.initState();
    search("");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Sent Requests",
              style:
                  GoogleFonts.merriweather(fontSize: 30, color: Colors.black)),
        ),
        body: Center(
          child: Consumer<UserProvider>(
            builder: (context, provider, child) {
              List<Widget> outgoingRequests = [];
              List<Widget> currentFriends = [];

              Map<String, dynamic> requests =
                  provider.userData?['outgoing_requests'] ?? {};
              Map<String, dynamic> friends = provider.userData?['friends'] ?? {};
              Map<String, dynamic> incomingRequests =
                  provider.userData?['friend_requests'] ?? {};

              requests.forEach((key, value) {
                outgoingRequests.add(FriendCard(
                  key: ValueKey('sent_$key'),
                  type: FriendCardType.sentRequest,
                  name: value['name'],
                  uid: key,
                  onPressed: () async {
                    // Refresh provider data and search results after action
                    await provider.loadUserData();
                    await search(_controller.text);
                  },
                ));
              });

              print("populating current friends list");
              friends.forEach((key, value) {
                print("key: $key, value: $value");
                currentFriends.add(FriendCard(
                  key: ValueKey('friend_$key'),
                  type: FriendCardType.currentFriend,
                  name: value['name'],
                  uid: key,
                  onPressed: () async {
                    // Refresh provider data and search results after action
                    await provider.loadUserData();
                    await search(_controller.text);
                  },
                ));
              });
              print("current friends list: $currentFriends");

              // Build search results list (excluding current friends and outgoing requests)
              combined.clear();

              for (var element in searchResults) {
                bool alreadyFriends = false;
                if (element['uid'] == Auth().user!.uid) {
                  continue;
                }
                var newFriend = FriendCard(
                  type: FriendCardType.addFriend,
                  name: element['name'],
                  uid: element['uid'],
                  onPressed: () {
                    setState(() {});
                  },
                );

                // check if the user is already a friend or part of outgoing requests
                for (var friend in currentFriends) {
                  if (friend is FriendCard) {
                    if (friend.uid == newFriend.uid) {
                      alreadyFriends = true;
                      break;
                    }
                  }
                }

                if (alreadyFriends) {
                  continue;
                }

                for (var request in outgoingRequests) {
                  if (request is FriendCard) {
                    if (request.uid == newFriend.uid) {
                      alreadyFriends = true;
                      break;
                    }
                  }
                }
                if (alreadyFriends) {
                  continue;
                }

                // Check if the user has already sent us a friend request
                if (incomingRequests.containsKey(element['uid'])) {
                  continue;
                }

                combined.add(FriendCard(
                  key: ValueKey('add_${element['uid']}'),
                  type: FriendCardType.addFriend,
                  name: element['name'],
                  uid: element['uid'],
                  onPressed: () async {
                    // Refresh provider data and search results after action
                    await provider.loadUserData();
                    await search(_controller.text);
                  },
                ));
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Add Friends",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          SizeConfig.blockSizeHorizontal! * 10,
                          0,
                          SizeConfig.blockSizeHorizontal! * 10,
                          0),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Search for friends",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (value) {
                          search(value);
                        },
                      ),
                    ),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 20,
                        child: Card(
                            color: Colors.blue,
                            child: combined.isEmpty
                                ? Center(
                                    child: Text(
                                      "No users found",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: combined.length,
                                    itemBuilder: (context, index) =>
                                        combined[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
                    const Text(
                      "Pending Friend Requests",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 20,
                        child: Card(
                            color: Colors.orange,
                            child: outgoingRequests.isEmpty
                                ? Center(
                                    child: Text(
                                      "No pending requests",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: outgoingRequests.length,
                                    itemBuilder: (context, index) =>
                                        outgoingRequests[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
                    const Text(
                      "Current Friends",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 20,
                        child: Card(
                            color: Colors.green,
                            child: currentFriends.isEmpty
                                ? Center(
                                    child: Text(
                                      "No friends yet",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: currentFriends.length,
                                    itemBuilder: (context, index) =>
                                        currentFriends[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ));
  }
}
