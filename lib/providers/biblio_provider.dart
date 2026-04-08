// ═══════════════════════════════════════════════════════════
// BIBLIO PROVIDER — Gestion état bibliothèque
// ═══════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

class BiblioProvider extends ChangeNotifier {
  String  _q    = '';
  String  _cat  = 'All';
  final   _lvl  = <String>[];
  String  _sort = 'recent';
  bool    _grid = true;
  final   _liked= <String>{};

  String       get query    => _q;
  String       get category => _cat;
  List<String> get levels   => List.unmodifiable(_lvl);
  String       get sort     => _sort;
  bool         get isGrid   => _grid;

  void setQuery(String v) { if (_q != v) { _q = v.toLowerCase(); notifyListeners(); } }
  void setCategory(String v) { if (_cat != v) { _cat = v; notifyListeners(); } }
  void toggleLevel(String v)  { _lvl.contains(v) ? _lvl.remove(v) : _lvl.add(v); notifyListeners(); }
  void setSort(String v)      { if (_sort != v) { _sort = v; notifyListeners(); } }
  void toggleGrid()           { _grid = !_grid; notifyListeners(); }
  void toggleLike(String id)  { _liked.contains(id) ? _liked.remove(id) : _liked.add(id); notifyListeners(); }
  bool isLiked(String id)     => _liked.contains(id);
  void reset() { _q=''; _cat='All'; _lvl.clear(); _sort='recent'; notifyListeners(); }

  String get cacheKey => '${_q}_${_cat}_${_lvl.join(',')}_$_sort';
}
