import 'package:flutter/foundation.dart';

import '../engine/best_in_slot.dart';
import '../engine/calculator.dart';
import '../engine/optimizer.dart';
import '../engine/spreadsheet_import.dart';
import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../repository/storage.dart';

/// Single source of truth for the whole app. Holds the current gear, the pet and
/// mount inventories, the build config and the equipped selection, and persists
/// every change to local JSON. Kept deliberately monolithic.
class AppState extends ChangeNotifier {
  AppState(
    this._storage, {
    required Map<GearSlot, GearPiece?> gear,
    required List<Pet> pets,
    required List<Mount> mounts,
    required BuildConfig config,
    required List<String> equippedPetIds,
    required String? equippedMountId,
    required int petSlots,
  })  : _gear = gear,
        _pets = pets,
        _mounts = mounts,
        _config = config,
        _equippedPetIds = equippedPetIds,
        _equippedMountId = equippedMountId,
        _petSlots = petSlots;

  final Storage _storage;

  final Map<GearSlot, GearPiece?> _gear;
  List<Pet> _pets;
  List<Mount> _mounts;
  BuildConfig _config;
  List<String> _equippedPetIds;
  String? _equippedMountId;
  int _petSlots;

  // --- Read access -----------------------------------------------------------

  Map<GearSlot, GearPiece?> get gear => Map.unmodifiable(_gear);
  List<Pet> get pets => List.unmodifiable(_pets);
  List<Mount> get mounts => List.unmodifiable(_mounts);
  BuildConfig get config => _config;
  int get petSlots => _petSlots;
  List<String> get equippedPetIds => List.unmodifiable(_equippedPetIds);
  String? get equippedMountId => _equippedMountId;

  GearPiece gearFor(GearSlot slot) => _gear[slot] ?? GearPiece.empty(slot);

  List<Pet> get equippedPets {
    final result = <Pet>[];
    for (final id in _equippedPetIds) {
      final pet = _firstOrNull(_pets.where((p) => p.id == id));
      if (pet != null) result.add(pet);
    }
    return result.take(_petSlots).toList();
  }

  Mount? get equippedMount =>
      _firstOrNull(_mounts.where((m) => m.id == _equippedMountId));

  /// The current build, computed through the single calculator entry point.
  BuildResult get currentBuild => Calculator.calculateBuild(
        gear: _gear,
        pets: equippedPets,
        mount: equippedMount,
        config: _config,
      );

  bool isPetEquipped(String id) => _equippedPetIds.contains(id);
  bool isMountEquipped(String id) => _equippedMountId == id;

  // --- Gear --------------------------------------------------------------------

  void setGear(GearSlot slot, GearPiece piece) {
    _gear[slot] = piece;
    _persistGear();
    notifyListeners();
  }

  // --- Pets --------------------------------------------------------------------

  void addPet(Pet pet) {
    _pets = [..._pets, pet];
    _persistPets();
    notifyListeners();
  }

  /// Adds multiple pets at once (batch insert), each given a fresh id.
  void addPets(List<Pet> pets) {
    if (pets.isEmpty) return;
    _pets = [..._pets, for (final p in pets) p.copyWith(id: _newId())];
    _persistPets();
    notifyListeners();
  }

  void updatePet(Pet pet) {
    _pets = [for (final p in _pets) if (p.id == pet.id) pet else p];
    _persistPets();
    notifyListeners();
  }

  /// Replaces multiple pets at once (batch update), matched by id.
  void updatePets(List<Pet> pets) {
    if (pets.isEmpty) return;
    final byId = {for (final p in pets) p.id: p};
    _pets = [for (final p in _pets) byId[p.id] ?? p];
    _persistPets();
    notifyListeners();
  }

  void deletePet(String id) {
    _pets = _pets.where((p) => p.id != id).toList();
    _equippedPetIds = _equippedPetIds.where((e) => e != id).toList();
    _persistPets();
    _persistEquipped();
    notifyListeners();
  }

  Pet duplicatePet(Pet pet) {
    final copy = pet.copyWith(id: _newId());
    _pets = [..._pets, copy];
    _persistPets();
    notifyListeners();
    return copy;
  }

  void togglePetEquipped(String id) {
    if (_equippedPetIds.contains(id)) {
      _equippedPetIds = _equippedPetIds.where((e) => e != id).toList();
    } else {
      final next = [..._equippedPetIds, id];
      // Keep only the most recent [petSlots] selections equipped.
      _equippedPetIds = next.length > _petSlots
          ? next.sublist(next.length - _petSlots)
          : next;
    }
    _persistEquipped();
    notifyListeners();
  }

  // --- Mounts ------------------------------------------------------------------

  void addMount(Mount mount) {
    _mounts = [..._mounts, mount];
    _persistMounts();
    notifyListeners();
  }

  /// Adds multiple mounts at once (batch insert), each given a fresh id.
  void addMounts(List<Mount> mounts) {
    if (mounts.isEmpty) return;
    _mounts = [..._mounts, for (final m in mounts) m.copyWith(id: _newId())];
    _persistMounts();
    notifyListeners();
  }

  void updateMount(Mount mount) {
    _mounts = [for (final m in _mounts) if (m.id == mount.id) mount else m];
    _persistMounts();
    notifyListeners();
  }

  /// Replaces multiple mounts at once (batch update), matched by id.
  void updateMounts(List<Mount> mounts) {
    if (mounts.isEmpty) return;
    final byId = {for (final m in mounts) m.id: m};
    _mounts = [for (final m in _mounts) byId[m.id] ?? m];
    _persistMounts();
    notifyListeners();
  }

  void deleteMount(String id) {
    _mounts = _mounts.where((m) => m.id != id).toList();
    if (_equippedMountId == id) _equippedMountId = null;
    _persistMounts();
    _persistEquipped();
    notifyListeners();
  }

  Mount duplicateMount(Mount mount) {
    final copy = mount.copyWith(id: _newId());
    _mounts = [..._mounts, copy];
    _persistMounts();
    notifyListeners();
    return copy;
  }

  void equipMount(String? id) {
    _equippedMountId = (_equippedMountId == id) ? null : id;
    _persistEquipped();
    notifyListeners();
  }

  /// Sets the equipped mount directly (no toggling). Used by the optimizer to
  /// apply a recommended loadout.
  void setEquippedMount(String? id) {
    _equippedMountId = id;
    _persistEquipped();
    notifyListeners();
  }

  /// Replaces the equipped pets with the given ids (capped at [petSlots]). Used
  /// by the optimizer to apply a recommended loadout.
  void setEquippedPets(List<String> ids) {
    _equippedPetIds = ids.take(_petSlots).toList();
    _persistEquipped();
    notifyListeners();
  }

  // --- Config ------------------------------------------------------------------

  void setConfig(BuildConfig config) {
    _config = config;
    _storage.writeObject(_kConfig, config.toJson());
    notifyListeners();
  }

  void setPetSlots(int slots) {
    _petSlots = slots.clamp(1, 6).toInt();
    _storage.writeInt(_kPetSlots, _petSlots);
    notifyListeners();
  }

  // --- Optimizer ---------------------------------------------------------------

  OptimizerOutput runOptimizer() => Optimizer.run(
        gear: _gear,
        pets: _pets,
        mounts: _mounts,
        config: _config,
        petSlots: _petSlots,
      );

  /// Ceiling for [mode] if every current gear piece's existing substat slots
  /// rolled ideally, holding main stats fixed. Pets/mount are held fixed too
  /// when included, or left out of the calculation entirely when not.
  BestInSlotResult bestInSlot({
    required OptimizationMode mode,
    bool includePets = true,
    bool includeMount = true,
  }) =>
      BestInSlot.solve(
        gear: _gear,
        pets: includePets ? equippedPets : const [],
        mount: includeMount ? equippedMount : null,
        config: _config,
        mode: mode,
      );

  // --- Persistence -------------------------------------------------------------

  static const String _kGear = 'gear';
  static const String _kPets = 'pets';
  static const String _kMounts = 'mounts';
  static const String _kConfig = 'config';
  static const String _kEquipped = 'equipped';
  static const String _kPetSlots = 'petSlots';

  void _persistGear() {
    _storage.writeList(
      _kGear,
      [for (final p in _gear.values) if (p != null) p.toJson()],
    );
  }

  void _persistPets() =>
      _storage.writeList(_kPets, [for (final p in _pets) p.toJson()]);

  void _persistMounts() =>
      _storage.writeList(_kMounts, [for (final m in _mounts) m.toJson()]);

  void _persistEquipped() {
    _storage.writeObject(_kEquipped, {
      'pets': _equippedPetIds,
      'mount': _equippedMountId,
    });
  }

  /// Replaces the current gear, config and equipped loadout with an imported
  /// profile, and adds the imported pets and mount to the inventory.
  void applyImport(ImportedProfile imported) {
    for (final entry in imported.gear.entries) {
      _gear[entry.key] = entry.value;
    }

    final petIds = <String>[];
    final nextPets = [..._pets];
    for (final pet in imported.pets) {
      final withId = pet.copyWith(id: _newId());
      nextPets.add(withId);
      petIds.add(withId.id);
    }
    _pets = nextPets;

    String? mountId;
    if (imported.mount != null) {
      final withId = imported.mount!.copyWith(id: _newId());
      _mounts = [..._mounts, withId];
      mountId = withId.id;
    }

    _equippedPetIds = petIds.take(_petSlots).toList();
    _equippedMountId = mountId;
    _config = imported.config;

    _persistGear();
    _persistPets();
    _persistMounts();
    _persistEquipped();
    _storage.writeObject(_kConfig, _config.toJson());
    notifyListeners();
  }

  /// Full snapshot of everything persisted, for transferring a profile to
  /// another device by exporting this to a .json file and importing it there.
  Map<String, dynamic> exportAll() => {
        'version': 1,
        'gear': [for (final p in _gear.values) if (p != null) p.toJson()],
        'pets': [for (final p in _pets) p.toJson()],
        'mounts': [for (final m in _mounts) m.toJson()],
        'config': _config.toJson(),
        'equipped': {'pets': _equippedPetIds, 'mount': _equippedMountId},
        'petSlots': _petSlots,
      };

  /// Replaces every piece of persisted state with a snapshot from
  /// [exportAll], as produced on another device.
  void importAll(Map<String, dynamic> json) {
    final gear = <GearSlot, GearPiece?>{
      for (final slot in GearSlot.values) slot: GearPiece.empty(slot),
    };
    for (final raw in (json['gear'] as List?) ?? const []) {
      final piece = GearPiece.fromJson(raw as Map<String, dynamic>);
      gear[piece.slot] = piece;
    }
    _gear
      ..clear()
      ..addAll(gear);

    _pets = ((json['pets'] as List?) ?? const [])
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
    _mounts = ((json['mounts'] as List?) ?? const [])
        .map((e) => Mount.fromJson(e as Map<String, dynamic>))
        .toList();

    final configJson = json['config'] as Map<String, dynamic>?;
    _config =
        configJson != null ? BuildConfig.fromJson(configJson) : const BuildConfig();

    final equipped = json['equipped'] as Map<String, dynamic>?;
    _equippedPetIds = ((equipped?['pets'] as List?) ?? const [])
        .map((e) => e as String)
        .toList();
    _equippedMountId = equipped?['mount'] as String?;

    _petSlots = (json['petSlots'] as num?)?.toInt() ?? _petSlots;

    _persistGear();
    _persistPets();
    _persistMounts();
    _persistEquipped();
    _storage.writeObject(_kConfig, _config.toJson());
    _storage.writeInt(_kPetSlots, _petSlots);
    notifyListeners();
  }

  static int _idCounter = 0;

  static String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$stamp${(_idCounter++).toRadixString(36)}';
  }

  /// Loads persisted state, or sensible defaults on first launch.
  static Future<AppState> load(Storage storage) async {
    final gear = <GearSlot, GearPiece?>{
      for (final slot in GearSlot.values) slot: GearPiece.empty(slot),
    };
    for (final raw in storage.readList(_kGear)) {
      final piece = GearPiece.fromJson(raw as Map<String, dynamic>);
      gear[piece.slot] = piece;
    }

    final pets = storage
        .readList(_kPets)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();

    final mounts = storage
        .readList(_kMounts)
        .map((e) => Mount.fromJson(e as Map<String, dynamic>))
        .toList();

    final configJson = storage.readObject(_kConfig);
    final config = configJson != null
        ? BuildConfig.fromJson(configJson)
        : const BuildConfig();

    final equipped = storage.readObject(_kEquipped);
    final equippedPetIds = ((equipped?['pets'] as List?) ?? const [])
        .map((e) => e as String)
        .toList();
    final equippedMountId = equipped?['mount'] as String?;

    final petSlots = storage.readInt(_kPetSlots) ?? 3;

    return AppState(
      storage,
      gear: gear,
      pets: pets,
      mounts: mounts,
      config: config,
      equippedPetIds: equippedPetIds,
      equippedMountId: equippedMountId,
      petSlots: petSlots,
    );
  }
}

/// Returns the first element of [items], or null when the iterable is empty.
/// A small local helper so the state layer needs no extra package.
T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
