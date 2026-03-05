import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/events/data/models/event_model.dart';
import 'add_event_screen.dart';
import 'edit_event_screen.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/sidebar.dart';
import 'package:tms_flutter/features/admin/layout/presentation/widgets/header.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final List<EventModel> _events = [
    EventModel(
      id: '1', eventName: 'Padel',
      description: 'Annual padel tournament at Wankhede',
      startDate: '2025-12-10', endDate: '2025-12-13',
      venueId: 'v1', venueName: 'Wankhede Stadium',
      banner: '', domain: '', status: 'Published',
    ),
    EventModel(
      id: '2', eventName: 'Cricket',
      description: 'Inter-college cricket championship',
      startDate: '2025-12-11', endDate: '2025-12-13',
      venueId: 'v2', venueName: 'Xavier',
      banner: '', domain: '', status: 'Draft',
    ),
  ];

  String _searchQuery = '';

  List<EventModel> get _filtered => _events
      .where((e) =>
          e.eventName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.venueName.toLowerCase().contains(_searchQuery.toLowerCase()))
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
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDelete(EventModel event) {
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
              const Text("Delete Event",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${event.eventName}"?\nThis action cannot be undone.',
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
                          _events.removeWhere((e) => e.id == event.id));
                      Navigator.pop(context);
                      _showSnack('"${event.eventName}" deleted successfully');
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
      builder: (_) => AddEventScreen(
        onSave: (EventModel newEvent) {
          setState(() => _events.add(newEvent));
          _showSnack('"${newEvent.eventName}" created successfully!');
        },
      ),
    );
  }

  void _openEdit(EventModel event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditEventScreen(
        event: event,
        onSave: (EventModel updated) {
          setState(() {
            final i = _events.indexWhere((e) => e.id == updated.id);
            if (i != -1) _events[i] = updated;
          });
          _showSnack('"${updated.eventName}" updated successfully!');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _events.where((e) => e.status == 'Published').length;
    final draft     = _events.where((e) => e.status == 'Draft').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Page title + button ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Event Master",
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A46D8))),
                  const SizedBox(height: 3),
                  Text("Manage all sports events",
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              // ElevatedButton handles hover natively — zero flicker
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create Event",
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
            _StatCard(
                label: "Total Events",
                value: "${_events.length}",
                icon: Icons.event_note_outlined,
                color: const Color(0xFF0A46D8)),
            const SizedBox(width: 14),
            _StatCard(
                label: "Published",
                value: "$published",
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF16A34A)),
            const SizedBox(width: 14),
            _StatCard(
                label: "Draft",
                value: "$draft",
                icon: Icons.edit_note_outlined,
                color: const Color(0xFF6B7280)),
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
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search by event name or venue...",
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

          // ── Table card ───────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(children: [

                // ── Column headers ───────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFF),
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(children: [
                    _colHead("",           flex: 2),  // banner
                    _colHead("EVENT",      flex: 3),
                    _colHead("VENUE",      flex: 3),
                    _colHead("START DATE", flex: 2),
                    _colHead("END DATE",   flex: 2),
                    _colHead("STATUS",     flex: 2),
                    _colHead("ACTIONS",    flex: 2, center: true),
                  ]),
                ),

                // ── Data rows ────────────────────────────
                _filtered.isEmpty
                    ? _buildEmpty()
                    : Column(
                        children: List.generate(_filtered.length, (i) {
                          final isLast = i == _filtered.length - 1;
                          return _EventRow(
                            event: _filtered[i],
                            isLast: isLast,
                            onEdit: () => _openEdit(_filtered[i]),
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
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle),
              child: const Icon(Icons.event_busy_outlined,
                  size: 34, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            const Text("No events found",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            const Text("Click '+ Create Event' to get started",
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF))),
          ]),
        ),
      );
}

// ── Event Row ─────────────────────────────────────────────────
// Uses Material + InkWell — hover is GPU-side, zero setState, zero blink
class _EventRow extends StatelessWidget {
  final EventModel event;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventRow({
    required this.event,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final e = event;

    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16))
              : BorderRadius.zero,
          child: InkWell(
            onTap: () {},
            hoverColor: const Color(0xFFF0F5FF),  // smooth blue tint
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16))
                : BorderRadius.zero,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // ── Banner ──────────────────────────────
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: 72, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: e.banner.isEmpty
                          ? const Icon(Icons.image_outlined,
                              color: Color(0xFFD1D5DB), size: 22)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(e.banner,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined,
                                          color: Color(0xFFD1D5DB)))),
                    ),
                  ),

                  // ── Event name + description ─────────────
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.eventName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF111827))),
                        if (e.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(e.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF))),
                          ),
                      ],
                    ),
                  ),

                  // ── Venue ────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(e.venueName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280))),
                      ),
                    ]),
                  ),

                  // ── Start date ───────────────────────────
                  Expanded(
                    flex: 2,
                    child: _DatePill(date: e.startDate),
                  ),

                  // ── End date ─────────────────────────────
                  Expanded(
                    flex: 2,
                    child: _DatePill(date: e.endDate),
                  ),

                  // ── Status badge ─────────────────────────
                  Expanded(
                    flex: 2,
                    child: _StatusBadge(status: e.status),
                  ),

                  // ── Action buttons ───────────────────────
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RowActionBtn(
                          icon: Icons.edit_outlined,
                          color: const Color(0xFFF59E0B),
                          tooltip: "Edit Event",
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 8),
                        _RowActionBtn(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444),
                          tooltip: "Delete Event",
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
      ],
    );
  }
}

// ── Date pill ─────────────────────────────────────────────────
class _DatePill extends StatelessWidget {
  final String date;
  const _DatePill({required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.calendar_today_outlined,
          size: 12, color: Color(0xFF9CA3AF)),
      const SizedBox(width: 5),
      Text(date,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280))),
    ]);
  }
}

// ── Status badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'Published';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPublished
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: isPublished
                ? const Color(0xFF16A34A)
                : const Color(0xFF9CA3AF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(status,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPublished
                    ? const Color(0xFF15803D)
                    : const Color(0xFF6B7280))),
      ]),
    );
  }
}

// ── Row action button — Material InkWell, no setState ─────────
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
  Widget build(BuildContext context) {
    return Tooltip(
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
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
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
}