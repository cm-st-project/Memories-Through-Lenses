import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  List<GroupCard> searchedGroups = [];
  List<GroupCard> pendingGroups = [];
  String? userSchool;
  bool isLoadingGroups = true;
  bool isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    loadUserSchool();
    getGroupRequests();
  }

  Future<void> loadUserSchool() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          userSchool = userDoc.data()?['school'];
        });
      }

      // Load groups regardless of whether school is set
      // If no school, will show all public groups
      await getGroupsCollection();
    } catch (e) {
      print('Error loading user school: $e');
      if (mounted) {
        setState(() {
          isLoadingGroups = false;
        });
      }
    }
  }

  Future<void> getGroupsCollection() async {
    try {
      setState(() {
        isLoadingGroups = true;
      });

      searchedGroups.clear();

      // Get user data for group_requests and current groups
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      // group_requests might be an array or a map
      var groupRequestsData = userDoc.data()?['group_requests'];
      List<String> groupRequests = [];

      if (groupRequestsData is List) {
        groupRequests = List<String>.from(groupRequestsData);
      } else if (groupRequestsData is Map) {
        groupRequests = List<String>.from((groupRequestsData as Map).keys);
      }

      List<dynamic> userGroups = userDoc.data()?['groups'] ?? [];

      print('==================== JOIN GROUP DEBUG ====================');
      print('User school: $userSchool');
      print('User group requests type: ${groupRequestsData.runtimeType}');
      print('User group requests: $groupRequests');
      print('User groups: $userGroups');
      print('User ID: ${Auth().user!.uid}');

      // Fetch all public groups (or by school if available)
      Query query = FirebaseFirestore.instance
          .collection('groups')
          .where('private', isEqualTo: false);

      // Only filter by school if user has a school assigned
      if (userSchool != null && userSchool!.isNotEmpty) {
        query = query.where('school', isEqualTo: userSchool);
      }

      QuerySnapshot snapshot = await query.get();

      print('Total public groups found: ${snapshot.docs.length}');

      List<GroupCard> fetchedGroups = [];
      for (var doc in snapshot.docs) {
        // check that user is not owner of the group and not already a member
        List<dynamic> members = doc['members'] ?? [];

        bool isOwner = doc['owner'] == Auth().user!.uid;
        bool hasPendingRequest = groupRequests.contains(doc.id);
        bool isMember = members.contains(Auth().user!.uid) || userGroups.contains(doc.id);
        bool isPrivate = doc['private'] ?? false;


        if (!isOwner && !isMember) {
          fetchedGroups.add(GroupCard(
            name: doc['name'],
            groupID: doc.id,
            type: GroupCardType.request,
          ));
        }
      }


      if (mounted) {
        setState(() {
          searchedGroups = fetchedGroups;
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      print('Error loading groups: $e');
      if (mounted) {
        setState(() {
          isLoadingGroups = false;
        });
      }
    }
  }

  Future<void> search(String query) async {
    // Implement search functionality here
    if (query.isEmpty) {
      await getGroupsCollection();
    } else {
      setState(() {
        searchedGroups = searchedGroups
            .where((group) =>
                group.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  Future<void> getGroupRequests() async {
    try {
      setState(() {
        isLoadingPending = true;
      });

      pendingGroups.clear();

      // Fetch group requests from the user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      List<dynamic> groupRequests = userDoc.data()?['group_requests'] ?? [];

      for (var groupID in groupRequests) {
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupID)
            .get();

        if (groupDoc.exists && mounted) {
          Map<String, dynamic> groupData =
              groupDoc.data() as Map<String, dynamic>;
          setState(() {
            pendingGroups.add(GroupCard(
                name: groupData['name'],
                groupID: groupID,
                type: GroupCardType.pendingRequest));
          });
        }
      }

      if (mounted) {
        setState(() {
          isLoadingPending = false;
        });
      }
    } catch (e) {
      print('Error loading group requests: $e');
      if (mounted) {
        setState(() {
          isLoadingPending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Join Group',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Field
                Text(
                  'Search Groups',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) {
                    search(value);
                  },
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Search for a group to join...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Available Groups Section
                Text(
                  'Available Groups',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  height: SizeConfig.blockSizeVertical! * 35,
                  child: isLoadingGroups
                      ? const Center(child: CircularProgressIndicator())
                      : searchedGroups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.groups_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Groups Available',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      'You are already a member of all available public groups, or all groups are private',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: searchedGroups.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) => searchedGroups[index],
                            ),
                ),

                const SizedBox(height: 32),

                // Pending Requests Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pending Requests',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (pendingGroups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingGroups.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  height: SizeConfig.blockSizeVertical! * 25,
                  child: isLoadingPending
                      ? const Center(child: CircularProgressIndicator())
                      : pendingGroups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pending_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Pending Requests',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: pendingGroups.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) => pendingGroups[index],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
