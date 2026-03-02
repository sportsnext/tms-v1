import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAGE TITLE
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),

          const SizedBox(height: 25),

          // TOP STAT CARDS
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _statCard("Total Players", "1240"),
              _statCard("Total Teams", "98"),
              _statCard("Total Venues", "36"),
              _statCard("Active Tournaments", "12"),
            ],
          ),

          const SizedBox(height: 35),

          // SECOND ROW: ONGOING TOURNAMENTS + RECENT ACTIVITY
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;

              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  // ONGOING TOURNAMENTS — LEFT
                  Expanded(
                    flex: 2,
                    child: _tournamentsCard(),
                  ),

                  const SizedBox(width: 20, height: 20),

                  // RECENT ACTIVITY — RIGHT
                  Expanded(
                    flex: 1,
                    child: _activityCard(),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 35),

          // THIRD ROW: UPCOMING MATCHES + QUICK ACTIONS
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;

              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  // UPCOMING MATCHES — LEFT
                  Expanded(
                    flex: 2,
                    child: _upcomingMatchesCard(),
                  ),

                  const SizedBox(width: 20, height: 20),

                  // QUICK ACTIONS — RIGHT
                  Expanded(
                    flex: 1,
                    child: _quickActionsCard(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------
  // COMPONENTS BELOW
  // -------------------------

  Widget _statCard(String title, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tournamentsCard() {
    final tournaments = [
      {
        "name": "Champions Cricket League",
        "teams": "16 Teams",
        "date": "Feb 12 → Mar 28"
      },
      {
        "name": "National Football Cup",
        "teams": "12 Teams",
        "date": "Jan 5 → Feb 20"
      },
      {
        "name": "All India Badminton Open",
        "teams": "32 Teams",
        "date": "Mar 2 → Apr 9"
      },
    ];

    return _cardContainer(
      title: "Ongoing Tournaments",
      child: Column(
        children: tournaments
            .map(
              (t) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t["name"]!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        Text(t["teams"]!,
                            style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t["date"]!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _activityCard() {
    final activities = [
      "Player John Smith added to RCB",
      "Venue Wankhede Stadium updated",
      "New Event: Mumbai City Games created",
      "Team Delhi Lions registered",
    ];

    return _cardContainer(
      title: "Recent Activity",
      child: Column(
        children: activities
            .map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(a,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87))),
                    const SizedBox(width: 10),
                    const Text("Just now",
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _upcomingMatchesCard() {
    final matches = [
      {"match": "MI vs CSK", "venue": "Wankhede", "time": "Tomorrow 7:00 PM"},
      {"match": "RCB vs KKR", "venue": "Chinnaswamy", "time": "Feb 12, 5:30 PM"},
      {
        "match": "GT vs SRH",
        "venue": "Narendra Modi Stadium",
        "time": "Feb 14, 8:00 PM"
      },
    ];

    return _cardContainer(
      title: "Upcoming Matches",
      child: Column(
        children: matches
            .map(
              (m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m["match"]!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        Text(
                          m["venue"]!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        )
                      ],
                    ),
                    Text(m["time"]!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black87))
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context) {
    final actions = [
      "Create New Tournament",
      "Add Team",
      "Add Player",
      "Create Event",
      "Add Venue",
    ];

    return _cardContainer(
      title: "Quick Actions",
      child: Column(
        children: actions
            .map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 45,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigation later
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(a),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _cardContainer({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}