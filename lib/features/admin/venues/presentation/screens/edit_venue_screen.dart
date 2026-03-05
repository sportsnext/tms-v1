import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms_flutter/features/admin/venues/data/models/venue_model.dart';

// Place at: lib/features/admin/venues/presentation/screens/edit_venue_screen.dart

class EditVenueScreen extends StatefulWidget {
  final VenueModel venue;
  final void Function(VenueModel updated) onSave;
  const EditVenueScreen({super.key, required this.venue, required this.onSave});

  @override
  State<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends State<EditVenueScreen> {
  final _formKey     = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _mapUrlCtrl;
  late final TextEditingController _notesCtrl;

  late String            _status;
  late List<GroundModel> _grounds;
  bool _saving          = false;
  bool _locationVerified = false;
  bool _isSearching     = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    final v        = widget.venue;
    _nameCtrl      = TextEditingController(text: v.venueName);
    _addressCtrl   = TextEditingController(text: v.address);
    _cityCtrl      = TextEditingController(text: v.city);
    _stateCtrl     = TextEditingController(text: v.state);
    _countryCtrl   = TextEditingController(text: v.country);
    _latCtrl       = TextEditingController(text: v.latitude);
    _lngCtrl       = TextEditingController(text: v.longitude);
    _mapUrlCtrl    = TextEditingController(text: v.mapUrl);
    _notesCtrl     = TextEditingController(text: v.notes);
    _status        = v.status;
    _grounds       = List<GroundModel>.from(v.grounds);
    // If existing venue already has lat/lng, mark as verified
    _locationVerified = v.latitude.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _cityCtrl, _stateCtrl,
        _countryCtrl, _latCtrl, _lngCtrl, _mapUrlCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Nominatim search ─────────────────────────────────────
  Future<void> _searchVenue(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&addressdetails=1&limit=10'
        '&countrycodes=in'
        '&accept-language=en'
        '&q=${Uri.encodeComponent(query)}',
      );
      final res = await http.get(uri,
      headers: {
        'User-Agent': 'TMS-Flutter-App/1.0',
        'Accept-Language': 'en',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() => _searchResults =
            data.map((e) => e as Map<String, dynamic>).toList());
      }
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectFromSearch(Map<String, dynamic> place) {
    final addr    = place['address'] as Map<String, dynamic>? ?? {};
    final name    = (place['display_name'] as String).split(',').first.trim();
    final address = place['display_name'] as String? ?? '';
    final city    = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '') as String;
    final state   = (addr['state'] ?? '') as String;
    final country = (addr['country'] ?? '') as String;
    final lat     = place['lat'] as String? ?? '';
    final lng     = place['lon'] as String? ?? '';

    _nameCtrl.text    = name;
    _addressCtrl.text = address;
    _cityCtrl.text    = city;
    _stateCtrl.text   = state;
    _countryCtrl.text = country;
    _latCtrl.text     = lat;
    _lngCtrl.text     = lng;
    _mapUrlCtrl.clear();

    setState(() {
      _locationVerified = true;
      _searchResults    = [];
    });
  }

  void _clearLocation() {
    _latCtrl.clear();
    _lngCtrl.clear();
    _addressCtrl.clear();
    _cityCtrl.clear();
    _stateCtrl.clear();
    _countryCtrl.clear();
    _mapUrlCtrl.clear();
    setState(() {
      _locationVerified = false;
      _searchResults    = [];
    });
  }

  void _addGround() =>
      setState(() => _grounds.add(GroundModel.empty()));

  void _removeGround(int i) =>
      setState(() => _grounds.removeAt(i));

  void _updateGround(int i, GroundModel g) =>
      setState(() => _grounds[i] = g);

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latCtrl.text.trim().isEmpty && _mapUrlCtrl.text.trim().isEmpty) {
      _showError('Please select a location from search or enter a Map URL');
      return;
    }
    if (_grounds.isEmpty) {
      _showError('Please add at least one ground/court');
      return;
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final updated = widget.venue.copyWith(
      venueName: _nameCtrl.text.trim(),
      address:   _addressCtrl.text.trim(),
      city:      _cityCtrl.text.trim(),
      state:     _stateCtrl.text.trim(),
      country:   _countryCtrl.text.trim(),
      latitude:  _latCtrl.text.trim(),
      longitude: _lngCtrl.text.trim(),
      mapUrl:    _mapUrlCtrl.text.trim(),
      notes:     _notesCtrl.text.trim(),
      status:    _status,
      grounds:   _grounds,
    );

    setState(() => _saving = false);
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Container(
        width: 780,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: Column(children: [

          _ModalHeader(
            title:    "Edit Venue",
            subtitle: 'Editing "${widget.venue.venueName}"',
            onClose:  () => Navigator.pop(context),
            isEdit:   true,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _SectionTitle("Venue Details"),
                    const SizedBox(height: 14),

                    _FormLabel("Venue Name", required: true),
                    _VenueSearchField(
                      controller:       _nameCtrl,
                      locationVerified: _locationVerified,
                      isSearching:      _isSearching,
                      searchResults:    _searchResults,
                      onChanged:        _searchVenue,
                      onSelect:         _selectFromSearch,
                      onClear:          _clearLocation,
                    ),
                    const SizedBox(height: 16),

                    // Map URL shown when NOT verified
                    if (!_locationVerified) ...[
                      _FormLabel("Map URL (if location not found in search)"),
                      _FormField(
                        controller: _mapUrlCtrl,
                        hint: "Paste Google Maps or OpenStreetMap URL",
                        icon: Icons.link_rounded,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _FormLabel("Address"),
                    _FormField(
                      controller: _addressCtrl,
                      hint: "Full address",
                      icon: Icons.home_outlined,
                      readOnly: _locationVerified,
                    ),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("City"),
                          _FormField(controller: _cityCtrl, hint: "City",
                              icon: Icons.location_city_outlined,
                              readOnly: _locationVerified),
                        ],
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("State"),
                          _FormField(controller: _stateCtrl, hint: "State",
                              icon: Icons.map_outlined,
                              readOnly: _locationVerified),
                        ],
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("Country"),
                          _FormField(controller: _countryCtrl, hint: "Country",
                              icon: Icons.public_outlined,
                              readOnly: _locationVerified),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("Latitude"),
                          _FormField(controller: _latCtrl,
                              hint: "e.g. 18.9388",
                              icon: Icons.my_location,
                              readOnly: _locationVerified),
                        ],
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel("Longitude"),
                          _FormField(controller: _lngCtrl,
                              hint: "e.g. 72.8259",
                              icon: Icons.my_location,
                              readOnly: _locationVerified),
                        ],
                      )),
                    ]),

                    const SizedBox(height: 22),

                    _SectionTitle("Grounds / Courts"),
                    const SizedBox(height: 4),
                    Text("Add the courts or grounds available at this venue",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 14),

                    ..._grounds.asMap().entries.map((e) => _GroundCard(
                          index:    e.key,
                          ground:   e.value,
                          onUpdate: (g) => _updateGround(e.key, g),
                          onRemove: () => _removeGround(e.key),
                        )),

                    GestureDetector(
                      onTap: _addGround,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: Color(0xFF0A46D8), size: 20),
                            SizedBox(width: 8),
                            Text("Add Ground / Court",
                                style: TextStyle(
                                    color: Color(0xFF0A46D8),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    _SectionTitle("Additional Info"),
                    const SizedBox(height: 14),

                    _FormLabel("Notes (Optional)"),
                    _TextAreaField(
                      controller: _notesCtrl,
                      hint: "Any special notes about this venue...",
                    ),
                    const SizedBox(height: 16),

                    _FormLabel("Status"),
                    _StatusToggle(
                      value:     _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          _ModalFooter(
            saving:    _saving,
            saveLabel: "Update Venue",
            onCancel:  () => Navigator.pop(context),
            onSave:    _save,
          ),
        ]),
      ),
    );
  }
}
class _GroundCard extends StatelessWidget {
  final int         index;
  final GroundModel ground;
  final void Function(GroundModel) onUpdate;
  final VoidCallback onRemove;

  const _GroundCard({
    required this.index,
    required this.ground,
    required this.onUpdate,
    required this.onRemove,
  });

  static const _types = [
    'Cricket', 'Football', 'Padel', 'Tennis',
    'Badminton', 'Basketball', 'Volleyball', 'General',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF0A46D8).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text("${index + 1}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF0A46D8))),
              ),
            ),
            const SizedBox(width: 8),
            const Text("Ground / Court",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151))),
            const Spacer(),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded,
                  color: Colors.red.shade400, size: 20),
            ),
          ]),
          const SizedBox(height: 12),

          // Ground name
          TextField(
            onChanged: (v) => onUpdate(ground.copyWith(groundName: v)),
            controller: TextEditingController(text: ground.groundName)
              ..selection = TextSelection.collapsed(
                  offset: ground.groundName.length),
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco("Ground Name (e.g. Padel Court A)"),
          ),
          const SizedBox(height: 10),

          Row(children: [
            // Ground type dropdown
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border.fromBorderSide(
                      BorderSide(color: Color(0xFF93C5FD), width: 1.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _types.contains(ground.groundType)
                        ? ground.groundType
                        : 'General',
                    isExpanded: true,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF0A1D4A)),
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey.shade500),
                    items: _types
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onUpdate(ground.copyWith(groundType: v));
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Court count
            Expanded(
              flex: 1,
              child: TextField(
                keyboardType: TextInputType.number,
                onChanged: (v) => onUpdate(ground.copyWith(
                    courtCount: int.tryParse(v) ?? 1)),
                controller: TextEditingController(
                    text: "${ground.courtCount}")
                  ..selection = TextSelection.collapsed(
                      offset: "${ground.courtCount}".length),
                style: const TextStyle(fontSize: 13),
                decoration:
                    _inputDeco("Courts"),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF93C5FD))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF93C5FD), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF0A46D8), width: 2)),
      );
}

// ── Venue search field with dropdown ─────────────────────────
class _VenueSearchField extends StatefulWidget {
  final TextEditingController               controller;
  final bool                                locationVerified;
  final bool                                isSearching;
  final List<Map<String, dynamic>>          searchResults;
  final void Function(String)               onChanged;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback                        onClear;

  const _VenueSearchField({
    required this.controller,
    required this.locationVerified,
    required this.isSearching,
    required this.searchResults,
    required this.onChanged,
    required this.onSelect,
    required this.onClear,
  });

  @override
  State<_VenueSearchField> createState() => _VenueSearchFieldState();
}

class _VenueSearchFieldState extends State<_VenueSearchField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Split display_name into primary (venue name) and secondary (rest of address)
  (String, String) _splitName(String displayName) {
    final parts = displayName.split(',');
    final primary   = parts.first.trim();
    final secondary = parts.length > 1
        ? parts.sublist(1).map((s) => s.trim()).join(', ')
        : '';
    return (primary, secondary);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Search bar ──────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.locationVerified
                  ? const Color(0xFF16A34A)
                  : _focused
                      ? const Color(0xFF0A46D8)
                      : const Color(0xFFD1D5DB),
              width: (_focused || widget.locationVerified) ? 2 : 1.5,
            ),
            boxShadow: _focused || widget.locationVerified
                ? [
                    BoxShadow(
                      color: widget.locationVerified
                          ? const Color(0xFF16A34A).withOpacity(0.12)
                          : const Color(0xFF0A46D8).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Row(children: [

            // Left icon — animated between search/spinner/check
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.locationVerified
                    ? const Icon(Icons.check_circle_rounded,
                        key: ValueKey('check'),
                        color: Color(0xFF16A34A), size: 22)
                    : widget.isSearching
                        ? const SizedBox(
                            key: ValueKey('spinner'),
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF0A46D8),
                            ))
                        : Icon(Icons.search_rounded,
                            key: const ValueKey('search'),
                            color: _focused
                                ? const Color(0xFF0A46D8)
                                : const Color(0xFF9CA3AF),
                            size: 22),
              ),
            ),

            // Text input
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                focusNode:  _focusNode,
                onChanged:  widget.onChanged,
                validator:  (v) => (v == null || v.trim().isEmpty)
                    ? 'Venue name is required'
                    : null,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0A1D4A)),
                decoration: InputDecoration(
                  hintText: widget.locationVerified
                      ? widget.controller.text
                      : "Search venue by name or city...",
                  hintStyle: TextStyle(
                      color: widget.locationVerified
                          ? const Color(0xFF15803D)
                          : Colors.grey.shade400,
                      fontSize: 15,
                      fontWeight: FontWeight.w400),
                  border:        InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder:   InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                ),
              ),
            ),

            // Right side: clear button OR "verified" chip
            if (widget.locationVerified)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onClear,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded,
                            size: 16, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text("Change",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade400)),
                      ]),
                    ),
                  ),
                ),
              )
            else if (widget.controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.cancel_rounded,
                          size: 18,
                          color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
          ]),
        ),

        // ── Verified badge ──────────────────────────────
        if (widget.locationVerified) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFF16A34A), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Location confirmed",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D))),
                    Text(
                      "Coordinates and address have been auto-filled from OpenStreetMap",
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],

        // ── Search results dropdown ─────────────────────
        if (widget.searchResults.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFFF8FAFF),
                    child: Row(children: [
                      const Icon(Icons.map_outlined,
                          size: 13, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.searchResults.length} locations found · powered by OpenStreetMap",
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),

                  // Results list
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: widget.searchResults.length,
                      itemBuilder: (_, i) {
                        final place = widget.searchResults[i];
                        final displayName =
                            place['display_name'] as String? ?? '';
                        final (primary, secondary) =
                            _splitName(displayName);
                        final type = place['type'] as String? ?? '';

                        return _SearchResultItem(
                          primary:   primary,
                          secondary: secondary,
                          type:      type,
                          onTap:     () => widget.onSelect(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── No results hint ─────────────────────────────
        if (!widget.isSearching &&
            !widget.locationVerified &&
            widget.controller.text.length >= 3 &&
            widget.searchResults.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "No locations found. You can still add the venue manually by entering a Map URL below.",
                  style: TextStyle(
                      fontSize: 12, color: Colors.amber.shade800),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ── Single search result item ─────────────────────────────────
class _SearchResultItem extends StatefulWidget {
  final String      primary;
  final String      secondary;
  final String      type;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.primary,
    required this.secondary,
    required this.type,
    required this.onTap,
  });

  @override
  State<_SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends State<_SearchResultItem> {
  bool _hovered = false;

  // Pick an icon based on place type
  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'stadium':
      case 'sports_centre':
        return Icons.stadium_outlined;
      case 'university':
      case 'school':
        return Icons.school_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'park':
        return Icons.park_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered
              ? const Color(0xFFF0F5FF)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Location pin icon container
              Container(
                margin: const EdgeInsets.only(top: 1),
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFF0A46D8).withOpacity(0.12)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForType(widget.type),
                  size: 17,
                  color: _hovered
                      ? const Color(0xFF0A46D8)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.primary,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _hovered
                              ? const Color(0xFF0A46D8)
                              : const Color(0xFF111827)),
                    ),
                    if (widget.secondary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow indicator on hover
              if (_hovered)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 6),
                  child: Icon(Icons.north_west_rounded,
                      size: 13, color: Color(0xFF0A46D8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF0A46D8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1D4A))),
      ]);
}

class _ModalHeader extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onClose;
  final bool isEdit;

  const _ModalHeader({
    required this.title, required this.subtitle,
    required this.onClose, required this.isEdit,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
        decoration: BoxDecoration(
          color: isEdit
              ? const Color(0xFFFFF7ED)
              : const Color(0xFFF0F5FF),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
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
              isEdit ? Icons.edit_location_outlined : Icons.add_location_outlined,
              color: isEdit
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF0A46D8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1D4A))),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
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

class _ModalFooter extends StatelessWidget {
  final bool saving;
  final String saveLabel;
  final VoidCallback onCancel, onSave;

  const _ModalFooter({
    required this.saving, required this.saveLabel,
    required this.onCancel, required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Text("Cancel",
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 14),
          Expanded(child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A46D8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(saveLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
          )),
        ]),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF374151))),
          if (required) ...[
            const SizedBox(width: 3),
            const Text("*",
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
      );
}

class _FormField extends StatelessWidget {
  final TextEditingController        controller;
  final String                       hint;
  final IconData                     icon;
  final bool                         readOnly;
  final String? Function(String?)?   validator;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.readOnly  = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        readOnly:   readOnly,
        validator:  validator,
        style: TextStyle(
            fontSize: 14,
            color: readOnly
                ? Colors.grey.shade500
                : const Color(0xFF0A1D4A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
          filled:    true,
          fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: readOnly
                      ? Colors.grey.shade200
                      : const Color(0xFF93C5FD),
                  width: 1.2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF0A46D8), width: 2)),
        ),
      );
}

class _TextAreaField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _TextAreaField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        minLines: 2, maxLines: 4,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0A1D4A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF93C5FD), width: 1.2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF0A46D8), width: 2)),
        ),
      );
}

class _StatusToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _StatusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        _StatusBtn(label: "Active",   active: value == 'Active',
            color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7),
            onTap: () => onChanged('Active')),
        const SizedBox(width: 10),
        _StatusBtn(label: "Inactive", active: value == 'Inactive',
            color: const Color(0xFF6B7280), bg: const Color(0xFFF3F4F6),
            onTap: () => onChanged('Inactive')),
      ]);
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final Color  color, bg;
  final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.active,
      required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: active ? bg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? color.withOpacity(0.5) : Colors.grey.shade300,
                width: active ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? color : Colors.grey.shade600)),
          ]),
        ),
      );
}