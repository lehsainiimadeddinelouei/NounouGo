import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// MODEL — Represents one availability slot (e.g. Monday 8h-17h)
// ─────────────────────────────────────────────────────────────
class Availability {
  final String? id;       // Firestore document ID (null when creating new)
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Availability({
    this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  // Convert to Map so Firestore can store it
  Map<String, dynamic> toMap() => {
    'day': day,
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
  };

  // Build an Availability from a Firestore document
  factory Availability.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Availability(
      id: doc.id,
      day: d['day'] ?? '',
      startTime: TimeOfDay(hour: d['startHour'] ?? 0, minute: d['startMinute'] ?? 0),
      endTime:   TimeOfDay(hour: d['endHour']   ?? 0, minute: d['endMinute']   ?? 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class BabysitterSetupScreen extends StatefulWidget {
  const BabysitterSetupScreen({super.key});

  @override
  State<BabysitterSetupScreen> createState() => _BabysitterSetupScreenState();
}

class _BabysitterSetupScreenState extends State<BabysitterSetupScreen> {

  // ── Constants ──────────────────────────────────────────────
  static const _pink   = Color(0xFFFF6B8A);
  static const _bg     = Color(0xFFFFF8F9);
  static const _teal   = Color(0xFF43C59E);
  static const _purple = Color(0xFF7C83FD);

  static const _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
    'Vendredi', 'Samedi', 'Dimanche',
  ];

  // One color per day (cycles through 4 colors)
  static const _dayColors = [_pink, _purple, _teal, Color(0xFFFFB347)];
  Color _colorFor(String day) => _dayColors[_days.indexOf(day) % _dayColors.length];

  // ── Firebase shortcuts ─────────────────────────────────────
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Profile document reference
  late final _profileRef = FirebaseFirestore.instance
      .collection('babysitters')
      .doc(_uid);

  // Availabilities sub-collection reference
  late final _availRef = _profileRef.collection('availabilities');

  // ── Helpers ────────────────────────────────────────────────
  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double _hours(Availability a) {
    final start = a.startTime.hour + a.startTime.minute / 60;
    final end   = a.endTime.hour   + a.endTime.minute   / 60;
    return (end - start).clamp(0, 24);
  }

  // ── Firestore write operations ─────────────────────────────

  // Save the Disponible / Non disponible toggle
  Future<void> _setStatus(bool value) =>
      _profileRef.set({'isAvailable': value}, SetOptions(merge: true));

  // Add a new slot or update an existing one
  Future<void> _saveSlot(Availability a) async {
    if (a.id != null) {
      await _availRef.doc(a.id).update(a.toMap());
    } else {
      await _availRef.add(a.toMap());
    }
  }

  // Delete a slot by its Firestore ID
  Future<void> _deleteSlot(String id) => _availRef.doc(id).delete();

  // ── Bottom sheet: Add or Edit a slot ──────────────────────
  void _openSlotSheet({Availability? slot}) {
    // Local state for the bottom sheet form
    var day   = slot?.day       ?? _days[0];
    var start = slot?.startTime ?? const TimeOfDay(hour: 8,  minute: 0);
    var end   = slot?.endTime   ?? const TimeOfDay(hour: 17, minute: 0);
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, refresh) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                slot == null ? 'Ajouter une disponibilité' : 'Modifier la disponibilité',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // ── Day picker (horizontal chips) ──────────────
              const Text('Jour',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _days.map((d) {
                    final selected = d == day;
                    return GestureDetector(
                      onTap: () => refresh(() => day = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? _pink : _pink.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          d.substring(0, 3),
                          style: TextStyle(
                            color: selected ? Colors.white : _pink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Time pickers ───────────────────────────────
              Row(children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Heure de début',
                    time: start,
                    color: _pink,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx, initialTime: start,
                        builder: (c, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(primary: _pink),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) refresh(() => start = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: 'Heure de fin',
                    time: end,
                    color: _pink,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx, initialTime: end,
                        builder: (c, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(primary: _pink),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) refresh(() => end = picked);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ── Save button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    refresh(() => saving = true);
                    await _saveSlot(Availability(
                      id: slot?.id,
                      day: day,
                      startTime: start,
                      endTime: end,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          slot == null ? 'Ajouter' : 'Mettre à jour',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation dialog ─────────────────────────────
  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous supprimer cette disponibilité ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSlot(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _pink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mes Disponibilités',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSlotSheet(),
        backgroundColor: _pink,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ajouter',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),

      // ── Two nested StreamBuilders:
      //    1. Listen to isAvailable (toggle status)
      //    2. Listen to the availabilities list
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileRef.snapshots(),
        builder: (context, profileSnap) {
          final isAvailable = profileSnap.data?.data()?['isAvailable'] ?? false;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _availRef.orderBy('day').snapshots(),
            builder: (context, availSnap) {

              // Show a loader the first time data arrives
              if (availSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Convert Firestore documents → Availability objects
              final slots = availSnap.data?.docs
                  .map((d) => Availability.fromDoc(d))
                  .toList() ?? [];

              // Total weekly hours (computed locally from the list)
              final totalHours = slots.fold(0.0, (sum, a) => sum + _hours(a));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Status toggle card ─────────────────────
                    _StatusCard(
                      isAvailable: isAvailable,
                      onToggle: _setStatus,
                    ),
                    const SizedBox(height: 20),

                    // ── Summary chips ──────────────────────────
                    Row(children: [
                      _SummaryChip(
                        icon: Icons.calendar_today_rounded,
                        label: '${slots.length} jours',
                        color: _pink,
                      ),
                      const SizedBox(width: 10),
                      _SummaryChip(
                        icon: Icons.access_time_rounded,
                        label: '${totalHours.toStringAsFixed(0)}h / semaine',
                        color: _purple,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Section heading ────────────────────────
                    Text(
                      'Mes créneaux (${slots.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Empty state or list of slots ───────────
                    if (slots.isEmpty)
                      _EmptyState(onAdd: () => _openSlotSheet())
                    else
                      ...slots.map((slot) => _SlotCard(
                        slot: slot,
                        color: _colorFor(slot.day),
                        fmt: _fmt,
                        hours: _hours(slot),
                        onEdit: () => _openSlotSheet(slot: slot),
                        onDelete: () => _confirmDelete(slot.id!),
                      )),

                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL WIDGETS — Each one does one thing only
// ─────────────────────────────────────────────────────────────

// Shows the Disponible / Non disponible toggle
class _StatusCard extends StatelessWidget {
  final bool isAvailable;
  final ValueChanged<bool> onToggle;
  const _StatusCard({required this.isAvailable, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF43C59E);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (isAvailable ? teal : Colors.grey).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
              color: isAvailable ? teal : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Statut de disponibilité',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(
                isAvailable ? 'Disponible' : 'Non disponible',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isAvailable ? teal : Colors.grey[600],
                ),
              ),
            ]),
          ),
          Switch.adaptive(
            value: isAvailable,
            onChanged: onToggle,
            activeColor: teal,
          ),
        ]),
      ),
    );
  }
}

// Colored pill with icon + label (e.g. "3 jours")
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

// One availability row card (day badge + time range + duration + menu)
class _SlotCard extends StatelessWidget {
  final Availability slot;
  final Color color;
  final String Function(TimeOfDay) fmt;
  final double hours;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SlotCard({
    required this.slot,
    required this.color,
    required this.fmt,
    required this.hours,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [

          // Day badge (e.g. "LUN")
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              slot.day.substring(0, 3).toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),

          // Day name + time range
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.day,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${fmt(slot.startTime)} – ${fmt(slot.endTime)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ]),
            ]),
          ),

          // Duration badge (e.g. "9h")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${hours.toStringAsFixed(0)}h',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),

          // Edit / Delete popup menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Modifier'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// Shown when the availability list is empty
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month_rounded, color: _pink, size: 48),
          ),
          const SizedBox(height: 16),
          Text('Aucune disponibilité',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            'Ajoutez vos créneaux disponibles\npour être trouvée par les familles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Ajouter un créneau', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ]),
      ),
    );
  }
}

// Tappable time display tile (used inside the bottom sheet)
class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.color, required this.onTap});

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.access_time_rounded, color: color, size: 16),
            const SizedBox(width: 6),
            Text(_fmt(time),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          ]),
        ]),
      ),
    );
  }
}
