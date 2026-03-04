import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl  = TextEditingController(text: "Admin User");
  final _emailCtrl = TextEditingController(text: "admin@sportsnext.in");
  final _phoneCtrl = TextEditingController(text: "+91 98765 43210");

  bool _editMode = false;
  bool _saving   = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _saving = false; _editMode = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully!"),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  // TODO: wire image_picker package here
  void _pickImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Add image_picker package and wire here"),
        backgroundColor: Color(0xFF0A46D8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text("My Profile",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A46D8))),
          const SizedBox(height: 4),
          const Text("Manage your personal information",
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 28),

          // Profile card
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(28),
            decoration: _cardDeco(),
            child: Column(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(height: 28),

                // Fields
                _buildField("Full Name",    _nameCtrl,  Icons.person_outline,  editable: _editMode),
                const SizedBox(height: 16),
                _buildField("Email",        _emailCtrl, Icons.email_outlined,   editable: false),
                const SizedBox(height: 16),
                _buildField("Phone Number", _phoneCtrl, Icons.phone_outlined,   editable: _editMode),
                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    if (!_editMode)
                      _HoverBtn(
                        label: "Edit Profile",
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF0A46D8),
                        onTap: () => setState(() => _editMode = true),
                      )
                    else ...[
                      _HoverBtn(
                        label: _saving ? "Saving..." : "Save Changes",
                        icon: Icons.check_rounded,
                        color: const Color(0xFF16A34A),
                        onTap: _saving ? null : _saveProfile,
                      ),
                      const SizedBox(width: 12),
                      _HoverBtn(
                        label: "Cancel",
                        icon: Icons.close_rounded,
                        color: Colors.grey,
                        outlined: true,
                        onTap: () => setState(() => _editMode = false),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Change password card
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(28),
            decoration: _cardDeco(),
            child: const _ChangePasswordSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: const Color(0xFF0A46D8).withOpacity(0.1),
          child: const Icon(Icons.person, size: 52, color: Color(0xFF0A46D8)),
        ),
        Positioned(
          bottom: 0, right: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A46D8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      IconData icon, {bool editable = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: editable,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0A1D4A)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            filled: true,
            fillColor: editable ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF0A46D8), width: 2)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      );
}

// ── Change Password ───────────────────────────────────────────
class _ChangePasswordSection extends StatefulWidget {
  const _ChangePasswordSection();
  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _saving         = false;
  String? _error;

  Future<void> _changePassword() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = "New passwords do not match");
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = "Password must be at least 6 characters");
      return;
    }
    setState(() { _saving = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _saving = false);
    _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password changed successfully!"),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Change Password",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1D4A))),
        const SizedBox(height: 20),
        _passField("Current Password", _currentCtrl, _obscureCurrent,
            () => setState(() => _obscureCurrent = !_obscureCurrent)),
        const SizedBox(height: 14),
        _passField("New Password", _newCtrl, _obscureNew,
            () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 14),
        _passField("Confirm New Password", _confirmCtrl, _obscureConfirm,
            () => setState(() => _obscureConfirm = !_obscureConfirm)),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 20),
        _HoverBtn(
          label: _saving ? "Updating..." : "Update Password",
          icon: Icons.lock_outline,
          color: const Color(0xFF0A46D8),
          onTap: _saving ? null : _changePassword,
        ),
      ],
    );
  }

  Widget _passField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: Colors.grey.shade500),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: Colors.grey.shade500),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF0A46D8), width: 2)),
          ),
        ),
      ],
    );
  }
}

// ── Reusable hover button ─────────────────────────────────────
class _HoverBtn extends StatefulWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback? onTap;
  final bool outlined;

  const _HoverBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.outlined = false,
  });

  @override
  State<_HoverBtn> createState() => _HoverBtnState();
}

class _HoverBtnState extends State<_HoverBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.outlined
                ? (_hovered ? widget.color.withOpacity(0.08) : Colors.transparent)
                : (_hovered ? widget.color.withOpacity(0.85) : widget.color),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16,
                  color: widget.outlined ? widget.color : Colors.white),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.outlined ? widget.color : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}