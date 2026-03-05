import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/venues/data/models/venue_model.dart';
import 'add_venue_screen.dart';
import 'edit_venue_screen.dart';

// Place at: lib/features/admin/venues/presentation/screens/venue_list_screen.dart

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  // TODO: Replace with GET /api/venues/all
  final List<VenueModel> _venues = [
    VenueModel(
      id: 'v1', venueName: 'Wankhede Stadium',
      address: 'D Rd, Churchgate, Mumbai, Maharashtra 400020',
      city: 'Mumbai', state: 'Maharashtra', country: 'India',
      latitude: '18.9388', longitude: '72.8259',
      mapUrl: '', notes: 'Main cricket stadium', status: 'Active',
      grounds: [
        GroundModel(groundName: 'Main Cricket Ground', groundType: 'Cricket', courtCount: 1),
      ],
    ),
    VenueModel(
      id: 'v2', venueName: 'Xavier Grounds',
      address: 'St. Xavier\'s College, Mumbai, Maharashtra',
      city: 'Mumbai', state: 'Maharashtra', country: 'India',
      latitude: '18.9435', longitude: '72.8317',
      mapUrl: '', notes: 'Multi-sport ground', status: 'Active',
      grounds: [
        GroundModel(groundName: 'Football Turf', groundType: 'Football', courtCount: 1),
        GroundModel(groundName: 'Badminton Court', groundType: 'Badminton', courtCount: 4),
      ],
    ),
  ];

  String _searchQuery = '';

  List<VenueModel> get _filtered => _venues
      .where((v) =>
          v.venueName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.state.toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDelete(VenueModel venue) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade600, size: 32),
              ),
              const SizedBox(height: 16),
              const Text("Delete Venue",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${venue.venueName}"?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text("Cancel",
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() =>
                          _venues.removeWhere((v) => v.id == venue.id));
                      Navigator.pop(context);
                      _showSnack('"${venue.venueName}" deleted successfully');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Delete",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _openAdd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddVenueScreen(
        onSave: (VenueModel newVenue) {
          setState(() => _venues.add(newVenue));
          _showSnack('"${newVenue.venueName}" added successfully!');
        },
      ),
    );
  }

  void _openEdit(VenueModel venue) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditVenueScreen(
        venue: venue,
        onSave: (VenueModel updated) {
          setState(() {
            final i = _venues.indexWhere((v) => v.id == updated.id);
            if (i != -1) _venues[i] = updated;
          });
          _showSnack('"${updated.venueName}" updated successfully!');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active   = _venues.where((v) => v.status == 'Active').length;
    final inactive = _venues.where((v) => v.status == 'Inactive').length;
    final courts   = _venues.fold<int>(0, (sum, v) => sum + v.totalCourts);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Title + button ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Venue Master",
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A46D8))),
                  const SizedBox(height: 3),
                  Text("Manage match locations and courts",
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Venue",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A46D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Stat cards ──────────────────────────────────
          Row(children: [
            _StatCard(label: "Total Venues",  value: "${_venues.length}", icon: Icons.location_on_outlined,     color: const Color(0xFF0A46D8)),
            const SizedBox(width: 14),
            _StatCard(label: "Active",        value: "$active",           icon: Icons.check_circle_outline,     color: const Color(0xFF16A34A)),
            const SizedBox(width: 14),
            _StatCard(label: "Inactive",      value: "$inactive",         icon: Icons.pause_circle_outline,     color: const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            _StatCard(label: "Total Courts",  value: "$courts",           icon: Icons.sports_outlined,          color: const Color(0xFFF59E0B)),
          ]),

          const SizedBox(height: 22),

          // ── Search ──────────────────────────────────────
          Material(
            elevation: 0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search by venue name, city or state...",
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey.shade400, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ── Table ───────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(children: [

                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFF),
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(children: [
                    _colHead("VENUE NAME",  flex: 3),
                    _colHead("LOCATION",    flex: 3),
                    _colHead("GROUNDS",     flex: 4),
                    _colHead("COURTS",      flex: 1),
                    _colHead("STATUS",      flex: 2),
                    _colHead("ACTIONS",     flex: 2, center: true),
                  ]),
                ),

                // Rows
                _filtered.isEmpty
                    ? _buildEmpty()
                    : Column(
                        children: List.generate(_filtered.length, (i) {
                          return _VenueRow(
                            venue:    _filtered[i],
                            isLast:   i == _filtered.length - 1,
                            onEdit:   () => _openEdit(_filtered[i]),
                            onDelete: () => _confirmDelete(_filtered[i]),
                          );
                        }),
                      ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colHead(String label,
      {int flex = 1, bool center = false}) =>
      Expanded(
        flex: flex,
        child: Text(label,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
                color: Color(0xFF6B7280))),
      );

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Center(
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6), shape: BoxShape.circle),
              child: const Icon(Icons.location_off_outlined,
                  size: 34, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            const Text("No venues found",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            const Text("Click '+ Add Venue' to get started",
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ]),
        ),
      );
}

// ── Venue row ─────────────────────────────────────────────────
class _VenueRow extends StatelessWidget {
  final VenueModel  venue;
  final bool        isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VenueRow({
    required this.venue,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final v        = venue;
    final isActive = v.status == 'Active';

    return Column(children: [
      Material(
        color: Colors.white,
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16))
            : BorderRadius.zero,
        child: InkWell(
          onTap: () {},
          hoverColor: const Color(0xFFF0F5FF),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Venue name + address
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.venueName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827))),
                      if (v.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(v.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF))),
                        ),
                    ],
                  ),
                ),

                // Location
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v.city.isNotEmpty || v.state.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              [v.city, v.state, v.country]
                                  .where((s) => s.isNotEmpty)
                                  .join(', '),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280)),
                            ),
                          ),
                        ]),
                      if (v.hasLocation)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            const Icon(Icons.my_location,
                                size: 11, color: Color(0xFF16A34A)),
                            const SizedBox(width: 3),
                            Text(
                              "${v.latitude}, ${v.longitude}",
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF16A34A)),
                            ),
                          ]),
                        )
                      else if (v.mapUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            const Icon(Icons.link,
                                size: 11, color: Color(0xFF0A46D8)),
                            const SizedBox(width: 3),
                            const Text("Map URL provided",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0A46D8))),
                          ]),
                        ),
                    ],
                  ),
                ),

                // Grounds chips
                Expanded(
                  flex: 4,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: v.grounds.map((g) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        "${g.groundName} (${g.courtCount})",
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A46D8)),
                      ),
                    )).toList(),
                  ),
                ),

                // Total courts
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${v.totalCourts}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706)),
                      ),
                    ),
                  ),
                ),

                // Status
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF9CA3AF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(v.status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF6B7280))),
                    ]),
                  ),
                ),

                // Actions
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RowActionBtn(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        tooltip: "Edit Venue",
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 8),
                      _RowActionBtn(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: "Delete Venue",
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (!isLast)
        const Divider(
            height: 1, thickness: 1,
            color: Color(0xFFF3F4F6),
            indent: 24, endIndent: 24),
    ]);
  }
}

// ── Stat card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                        height: 1)),
                const SizedBox(height: 3),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF))),
              ],
            ),
          ]),
        ),
      );
}

// ── Row action button ─────────────────────────────────────────
class _RowActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _RowActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: color.withOpacity(0.18),
            splashColor: color.withOpacity(0.15),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: color, size: 17),
            ),
          ),
        ),
      );
}