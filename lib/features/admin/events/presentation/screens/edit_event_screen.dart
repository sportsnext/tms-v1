import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tms_flutter/features/admin/events/data/models/event_model.dart';

// Place at: lib/features/admin/events/presentation/screens/edit_event_screen.dart

class EditEventScreen extends StatefulWidget {
  final EventModel event;
  final void Function(EventModel updated) onSave;

  const EditEventScreen({
    super.key,
    required this.event,
    required this.onSave,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _domainCtrl;

  late String _startDate;
  late String _endDate;
  late String _status;
  late String _venueId;
  late String _venueName;
  late String _banner;
  String _bannerName = ''; // ← NEW: stores filename
  bool _saving = false;

  final List<VenueOption> _venues = [
    VenueOption(id: 'v1', venueName: 'Wankhede Stadium'),
    VenueOption(id: 'v2', venueName: 'Xavier Grounds'),
    VenueOption(id: 'v3', venueName: 'DY Patil Stadium'),
    VenueOption(id: 'v4', venueName: 'Brabourne Stadium'),
  ];

  @override
  void initState() {
    super.initState();
    final e     = widget.event;
    _nameCtrl   = TextEditingController(text: e.eventName);
    _descCtrl   = TextEditingController(text: e.description);
    _domainCtrl = TextEditingController(text: e.domain);
    _startDate  = e.startDate;
    _endDate    = e.endDate;
    _status     = e.status;
    _venueId    = e.venueId;
    _venueName  = e.venueName;
    _banner     = e.banner;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0A46D8),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        if (isStart) _startDate = formatted;
        else         _endDate   = formatted;
      });
    }
  }

  // ── Banner picker — opens file system ────────────────────
  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _banner     = base64Encode(file.bytes!);
          _bannerName = file.name;
        });
      }
    }
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Event name is required';
    if (v.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  String? _validateDesc(String? v) {
    if (v == null || v.trim().isEmpty) return 'Description is required';
    return null;
  }

  bool _validateDates() {
    if (_startDate.isEmpty) { _showError('Please select a start date'); return false; }
    if (_endDate.isEmpty)   { _showError('Please select an end date');   return false; }
    if (_endDate.compareTo(_startDate) < 0) {
      _showError('End date cannot be before start date');
      return false;
    }
    return true;
  }

  bool _validateVenue() {
    if (_venueId.isEmpty) { _showError('Please select a venue'); return false; }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(msg),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateDates()) return;
    if (!_validateVenue()) return;

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final updated = widget.event.copyWith(
      eventName:   _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      startDate:   _startDate,
      endDate:     _endDate,
      venueId:     _venueId,
      venueName:   _venueName,
      banner:      _banner,
      domain:      _domainCtrl.text.trim(),
      status:      _status,
    );

    setState(() => _saving = false);
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 720,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 16)),
          ],
        ),
        child: Column(children: [
          _ModalHeader(
            title: "Edit Event",
            subtitle: 'Editing "${widget.event.eventName}"',
            onClose: () => Navigator.pop(context),
            isEdit: true,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel("Event Name", required: true),
                    _FormField(
                      controller: _nameCtrl,
                      hint: "Enter event name",
                      icon: Icons.event_outlined,
                      validator: _validateName,
                    ),
                    const SizedBox(height: 18),

                    _FormLabel("Description", required: true),
                    _TextAreaField(
                      controller: _descCtrl,
                      hint: "Write a short description...",
                      validator: _validateDesc,
                    ),
                    const SizedBox(height: 18),

                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("Start Date", required: true),
                          _DateField(
                            value: _startDate,
                            hint: "Select start date",
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ],
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("End Date", required: true),
                          _DateField(
                            value: _endDate,
                            hint: "Select end date",
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 18),

                    _FormLabel("Select Venue", required: true),
                    _VenueDropdown(
                      venues: _venues,
                      selectedId: _venueId,
                      onChanged: (venue) => setState(() {
                        _venueId   = venue.id;
                        _venueName = venue.venueName;
                      }),
                    ),
                    const SizedBox(height: 18),

                    _FormLabel("Custom Domain (Optional)"),
                    _FormField(
                      controller: _domainCtrl,
                      hint: "example.sportsmaster.in",
                      icon: Icons.language_outlined,
                    ),
                    const SizedBox(height: 18),

                    _FormLabel("Event Banner"),
                    _BannerUploader(
                      banner:     _banner,
                      bannerName: _bannerName,
                      onTap:      _pickBanner,
                      onRemove:   () => setState(() {
                        _banner     = '';
                        _bannerName = '';
                      }),
                    ),
                    const SizedBox(height: 18),

                    _FormLabel("Status"),
                    _StatusToggle(
                      value: _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          _ModalFooter(
            saving: _saving,
            saveLabel: "Update Event",
            onCancel: () => Navigator.pop(context),
            onSave: _save,
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════

class _ModalHeader extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onClose;
  final bool isEdit;

  const _ModalHeader({
    required this.title, required this.subtitle,
    required this.onClose, this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      decoration: BoxDecoration(
        color: isEdit ? const Color(0xFFFFF7ED) : const Color(0xFFF0F5FF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isEdit
                ? const Color(0xFFF59E0B).withOpacity(0.15)
                : const Color(0xFF0A46D8).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
            color: isEdit ? const Color(0xFFF59E0B) : const Color(0xFF0A46D8),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: Color(0xFF0A1D4A))),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        )),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close_rounded,
                  color: Colors.grey.shade600, size: 20),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ModalFooter extends StatelessWidget {
  final bool saving;
  final String saveLabel;
  final VoidCallback onCancel, onSave;

  const _ModalFooter({
    required this.saving, required this.saveLabel,
    required this.onCancel, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        Expanded(child: _FooterOutlineBtn(label: "Cancel", onTap: onCancel)),
        const SizedBox(width: 14),
        Expanded(child: _FooterSolidBtn(
            label: saving ? "Saving..." : saveLabel,
            onTap: saving ? () {} : onSave,
            saving: saving)),
      ]),
    );
  }
}

class _FooterSolidBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool saving;
  const _FooterSolidBtn(
      {required this.label, required this.onTap, required this.saving});

  @override
  State<_FooterSolidBtn> createState() => _FooterSolidBtnState();
}

class _FooterSolidBtnState extends State<_FooterSolidBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit:  (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.saving
                  ? Colors.grey.shade300
                  : (_h ? const Color(0xFF0835B0) : const Color(0xFF0A46D8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: widget.saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(widget.label,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ),
      );
}

class _FooterOutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterOutlineBtn({required this.label, required this.onTap});

  @override
  State<_FooterOutlineBtn> createState() => _FooterOutlineBtnState();
}

class _FooterOutlineBtnState extends State<_FooterOutlineBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit:  (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _h ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(child: Text(widget.label,
                style: TextStyle(color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600, fontSize: 14))),
          ),
        ),
      );
}

class _FormLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FormLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Text(text,
              style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13, color: Color(0xFF374151))),
          if (required) ...[
            const SizedBox(width: 3),
            const Text("*", style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
      );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller, required this.hint,
    required this.icon, this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0A1D4A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0A46D8), width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
      );
}

class _TextAreaField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _TextAreaField({
    required this.controller, required this.hint, this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        minLines: 3, maxLines: 5,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0A1D4A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0A46D8), width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
        ),
      );
}

class _DateField extends StatefulWidget {
  final String value, hint;
  final VoidCallback onTap;
  const _DateField({required this.value, required this.hint, required this.onTap});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.isNotEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? const Color(0xFF0A46D8) : const Color(0xFF93C5FD),
              width: _hovered ? 2 : 1.2,
            ),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 17,
                color: hasValue ? const Color(0xFF0A46D8) : Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(hasValue ? widget.value : widget.hint,
                style: TextStyle(fontSize: 14,
                    color: hasValue ? const Color(0xFF0A1D4A) : Colors.grey.shade400)),
          ]),
        ),
      ),
    );
  }
}

class _VenueDropdown extends StatelessWidget {
  final List<VenueOption> venues;
  final String selectedId;
  final void Function(VenueOption) onChanged;

  const _VenueDropdown({
    required this.venues, required this.selectedId, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId.isEmpty ? null : selectedId,
            hint: Text("Select Venue",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500),
            style: const TextStyle(fontSize: 14, color: Color(0xFF0A1D4A)),
            items: venues.map((v) => DropdownMenuItem<String>(
                value: v.id, child: Text(v.venueName))).toList(),
            onChanged: (id) {
              if (id == null) return;
              onChanged(venues.firstWhere((x) => x.id == id));
            },
          ),
        ),
      );
}

// ── Banner Uploader — with real file picker + preview ─────────
class _BannerUploader extends StatelessWidget {
  final String banner;
  final String bannerName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BannerUploader({
    required this.banner,
    required this.bannerName,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.isNotEmpty;

    return GestureDetector(
      onTap: hasImage ? null : onTap,
      child: Container(
        width: double.infinity,
        height: hasImage ? 160 : 120,
        decoration: BoxDecoration(
          color: hasImage ? Colors.grey.shade900 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.transparent : const Color(0xFF93C5FD),
            width: 1.5,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      Uri.parse('data:image/png;base64,$banner')
                          .data!
                          .contentAsBytes(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_outlined,
                            size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                  // Bottom bar with filename + Change + Remove
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.image_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bannerName.isNotEmpty ? bannerName : 'Existing banner',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A46D8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("Change",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("Remove",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 36, color: Colors.blue.shade300),
                  const SizedBox(height: 8),
                  Text("Click to upload banner",
                      style: TextStyle(
                          color: Colors.blue.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("PNG, JPG, WEBP supported",
                      style: TextStyle(
                          color: Colors.blue.shade300, fontSize: 11)),
                ],
              ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _StatusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        _StatusBtn(label: "Draft", active: value == 'Draft',
            activeColor: Colors.grey.shade700, activeBg: Colors.grey.shade200,
            onTap: () => onChanged('Draft')),
        const SizedBox(width: 10),
        _StatusBtn(label: "Published", active: value == 'Published',
            activeColor: Colors.green.shade700, activeBg: Colors.green.shade100,
            onTap: () => onChanged('Published')),
      ]);
}

class _StatusBtn extends StatefulWidget {
  final String label;
  final bool active;
  final Color activeColor, activeBg;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label, required this.active,
    required this.activeColor, required this.activeBg, required this.onTap,
  });

  @override
  State<_StatusBtn> createState() => _StatusBtnState();
}

class _StatusBtnState extends State<_StatusBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit:  (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: widget.active ? widget.activeBg
                  : (_h ? Colors.grey.shade50 : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active
                    ? widget.activeColor.withOpacity(0.5)
                    : Colors.grey.shade300,
                width: widget.active ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.active) ...[
                Icon(Icons.check_rounded, size: 16, color: widget.activeColor),
                const SizedBox(width: 6),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                      color: widget.active
                          ? widget.activeColor : Colors.grey.shade600)),
            ]),
          ),
        ),
      );
}