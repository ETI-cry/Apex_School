# Plan : Rendre la page Biblio instantanée avec StreamBuilder

## Contexte

**Problématique** : La page Biblio (bibliothèque de documents) n'affiche pas les nouveaux documents instantanément. Elle utilise une approche de **pagination manuelle** avec chargement au scroll et filtres appliqués localement.

**Solution demandée** : Appliquer le même pattern que la page **Entraide** qui utilise un `StreamBuilder` avec `snapshots()` de Firestore, ce qui permet :
- Affichage instantané des nouveaux documents
- Mise à jour en temps réel
- Suppression de la complexité de la pagination

## Analyse comparative

### Entraide page (modèle à suivre)
- Utilise `questionsStream()` qui retourne `Stream<List<QuestionModel>>`
- Query Firestore avec filtres (catégories, recherche, tri)
- Utilise `snapshots()` + `map()` pour convertir en modèle
- StreamBuilder directement dans `_buildQuestionList()`
- Pas de pagination, pas d'état complexe

### Biblio page (état actuel)
- `_loadDocs()` avec pagination (`limit`, `startAfterDocument`)
- État complexe : `_all`, `_shown`, `_loading`, `_hasMore`, `_ready`
- Filtrage différé : d'abord chargement brut dans `_all`, puis `_applyFilters()` vers `_shown`
- Microtasks pour éviter jank
- Précache des images en arrière-plan

## Approche d'implémentation

### 1. Créer `documentsStream()` dans `_BiblioService`

**Fichier** : `lib/screens/biblio_page.dart` (modifier la classe `_BiblioService`)

```dart
Stream<List<DocumentModel>> documentsStream({
  String query = '',
  String category = 'Tout',
  List<String> levels = const [],
  String sort = 'recent',
}) {
  // Construire la query Firestore de base
  Query q = FirebaseFirestore.instance
      .collection('documents')
      .where('isPublic', isEqualTo: true);

  // Filtre par catégorie (array-contains sur le champ category ? ou égalité simple)
  // Note: vérifier la structure des données - si catégorie est une chaîne simple
  if (category != 'Tout') {
    q = q.where('category', isEqualTo: category);
  }

  // Filtre par niveaux (array-contains-any)
  if (levels.isNotEmpty) {
    q = q.where('levels', arrayContainsAny: levels);
  }

  // Tri
  switch (sort) {
    case 'popular':
      q = q.orderBy('downloads', descending: true);
      break;
    case 'alphabetical':
      q = q.orderBy('title');
      break;
    default:
      q = q.orderBy('uploadDate', descending: true);
  }

  // IMPORTANT: Ne PAS mettre de limite si on veut tous les documents
  // Si la collection est très grande, on pourra éventuellement ajouter une limite
  // mais pour l'instant pas de pagination
  // q = q.limit(100); // Optionnel

  return q.snapshots().map((snap) {
    var docs = snap.docs
        .map((doc) => DocumentModel.fromFirestore(doc))
        .toList();

    // Filtrage côté client pour la recherche (car Firestore ne peut pas faire
    // searchScore complexe... si on a un champ searchKeywords, l'utiliser)
    if (query.isNotEmpty) {
      final lowerQ = query.toLowerCase();
      docs = docs.where((doc) => doc.matchesQuery(query)).toList();
      docs.sort((a, b) => b.searchScore(query).compareTo(a.searchScore(query)));
    }

    return docs;
  });
}
```

**Note** : Si la collection est énorme, on pourrait :
- Ajouter un champ `searchKeywords` dans Firestore pour la recherche côté serveur
- Mettre une limite (ex: 200 docs) pour éviter de charger tout
- Mais l'objectif est l'instantanéité, pas la pagination

### 2. Simplifier `_BiblioPageState`

**Fichier** : `lib/screens/biblio_page.dart`

Supprimer les variables d'état liées à la pagination et au chargement :
```dart
// À SUPPRIMER :
// var _loading = true;
// var _hasMore = true;
// var _ready = false;
// var _all = <DocumentModel>[];
// var _shown = <DocumentModel>[];
// DocumentSnapshot? _lastDoc;
```

Conserver uniquement :
- `_query`, `_cat`, `_sort`, `_lvl` (les filtres)
- `_isGridView` (vue grille/liste)
- `_scroll` controller
- Les booléens d'UI (`_searchFocused`, etc.)

Ajouter éventuellement un `bool _initialLoad = true` pour gérer le premier chargement (shimmer).

### 3. Remplacer `_buildContent()` avec StreamBuilder

**Nouveau `_buildContent()`** :

```dart
Widget _buildContent() {
  final p = context.watch<BiblioProvider>();

  return StreamBuilder<List<DocumentModel>>(
    stream: _service.documentsStream(
      query: _query,
      category: _cat == 'Tout' ? 'Tout' : _cat,
      levels: _lvl,
      sort: _sort,
    ),
    builder: (_, snap) {
      // État de chargement initial
      if (snap.connectionState == ConnectionState.waiting && _initialLoad) {
        return _buildShimmer(p.isGrid);
      }

      if (snap.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(
                'Erreur de connexion',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _initialLoad = true;
                  setState(() {});
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      }

      // Marquage comme chargé
      if (_initialLoad) {
        _initialLoad = false;
      }

      final documents = snap.data ?? [];

      if (documents.isEmpty) {
        return _buildEmpty();
      }

      // Précache des images (comme avant)
      final urls = documents
          .where((d) => d.isImage && d.imageUrl.isNotEmpty)
          .map((d) => d.imageUrl)
          .toList();
      _PrecacheService().precacheAll(urls);

      if (p.isGrid) {
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemCount: documents.length,
          itemBuilder: (_, i) {
            return RepaintBoundary(
              child: _gridCard(documents[i], i, p),
            );
          },
        );
      }

      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: documents.length,
        itemBuilder: (_, i) {
          return RepaintBoundary(
            child: _listCard(documents[i], i, p),
          );
        },
      );
    },
  );
}
```

### 4. Adapter les filtres en temps réel

Le StreamBuilder écoute déjà le stream avec les paramètres actuels. Lorsqu'un filtre change :
- Mettre à jour la variable d'état (`_query`, `_cat`, `_lvl`, `_sort`)
- Le StreamBuilder se reconstruit automatiquement avec le nouveau stream
- Firestore envoie les données filtrées en temps réel

**Pas besoin de `setState` sur les filtres** : ils sont déjà gérés par `BiblioProvider` (ChangeNotifier). Le Provider notifie et le widget se rebuild, créant un nouveau stream avec les nouveaux paramètres.

### 5. Conserver les animations

Les animations dans `_gridCard` et `_listCard` utilisent `Animate` avec `FadeEffect` et `SlideEffect`. Elles sont basées sur l'index `i`.

Avec le StreamBuilder, les documents arrivent en une seule fois (stream snapshot). Les animations restent valides car chaque item a son index dans la liste.

**Ajustement possible** : Si on veut des animations d'apparition lors des mises à jour du stream (nouveau document ajouté), il faudrait utiliser des clés uniques. Mais l'approche actuelle (index-based) devrait fonctionner.

### 6. Supprimer les méthodes de pagination obsolètes

Supprimer :
- `_loadDocs()`
- `_onScroll()`
- `_applyFilters()`
- `_lastDoc`
- Les listeners de scroll pour pagination

Garder le `_scroll` controller si besoin pour d'autres fonctionnalités (ex: scroll to top).

### 7. Gestion du cache et précache

Conserver le `_PrecacheService` et appeler `precacheAll()` après chaque snapshot pour charger les images en arrière-plan (comme actuellement).

### 8. Header, search bar, category chips

Ces widgets ne changent pas. Ils restent en haut et déclenchent des changements d'état dans `BiblioProvider`, ce qui reconstruit le StreamBuilder avec les nouveaux paramètres.

**Important** : Le header (`_buildHeader()` qui affiche le nombre de documents) doit s'adapter :
- Ancien : `'Bibliothèque · ${_shown.length} document${_shown.length > 1 ? 's' : ''}'`
- Nouveau : `'Bibliothèque · ${documents.length} document${documents.length > 1 ? 's' : ''}'`

Utiliser `snap.data?.length ?? 0`.

## Ordre d'implémentation recommandé

1. **Modifier `_BiblioService`** : ajouter `documentsStream()`
2. **Supprimer les variables d'état liées à la pagination** dans `_BiblioPageState`
3. **Remplacer `_buildContent()`** par la version StreamBuilder
4. **Mettre à jour `_buildHeader()`** pour utiliser `snap.data`
5. **Tester** : vérifier que les filtres (recherche, catégorie, niveaux, tri) fonctionnent en temps réel
6. **Vérifier les animations** et le shimmer de chargement
7. **Nettoyer** : supprimer les méthodes devenues inutiles

## Contraintes et considérations

- **Performance** : Charger tous les documents d'un coup peut être lent si la collection est énorme. On pourra ajouter une limite (ex: 200) et éventuellement un indicateur "Voir plus" si besoin. Mais l'objectif est l'instantanéité.
- **Recherche full-text** : Si Firestore ne supporte pas la recherche complexe (score, etc.), on garde le filtrage côté client. C'est acceptable si le nombre de documents reste raisonnable (< 500).
- **Mises à jour en temps réel** : Le stream se met à jour automatiquement quand un document est ajouté/modifié/supprimé dans Firestore. C'est le comportement souhaité.
- **Images** : Le précache reste indispensable pour une navigation fluide.
- **État de liked** : Géré par `BiblioProvider` (local state), pas de problème.

## Vérification

**Tests manuels** :
1. Lancement de l'app → shimmer de chargement → documents apparaissent
2. Changement de catégorie → documents filtrés instantanément
3. Recherche par mot-clé → résultats filtrés en temps réel
4. Ajout d'un nouveau document (via upload screen) → apparaît automatiquement dans Biblio sans refresh
5. Scroll → pas de pagination, tous les documents sont déjà là
6. Animation des items → OK

**Tests sur Firestore** :
- Ajouter/supprimer un document depuis la console Firebase → mise à jour immédiate dans l'app

## Fichiers à modifier

- `lib/screens/biblio_page.dart` (principal)
  - Ajouter `documentsStream()` dans `_BiblioService`
  - Simplifier `_BiblioPageState` (supprimer variables de pagination)
  - Remplacer `_buildContent()` par StreamBuilder
  - Mettre à jour `_buildHeader()`
  - Supprimer méthodes obsolètes (`_loadDocs`, `_applyFilters`, `_onScroll`)

**Note** : Aucun changement nécessaire dans les providers ou autres fichiers.
