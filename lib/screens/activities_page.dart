import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/apex_colors.dart';

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  // Apex color signature (sky blue)
  final Color deepOrange      = ApexColors.primary;
  final Color deepOrangeLight = ApexColors.accentLight;
  final Color deepOrangeDark  = ApexColors.primaryDark;

  // Apex color signature (sky blue + teal)
  final Color skyBlue         = ApexColors.accentLight;
  final Color skyBlueDark     = ApexColors.accent;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ========== APPBAR LUXURY ==========
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [deepOrangeDark, Colors.black]
                        : [deepOrange, Colors.white],
                  ),
                ),
                child: Stack(
                  children: [
                    // Motif décoratif
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deepOrange.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deepOrange.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Contenu
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACTIVITÉS",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Vivez l'expérience",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode 
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black87.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
           leading: IconButton(
  icon: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.black.withOpacity(0.3) 
              : Colors.white.withOpacity(0.3),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDarkMode ? Colors.white : Colors.black87,
          size: 18,
        ),
      ),
    ),
  ),
  onPressed: () => Navigator.pop(context),
),
          ),

          // ========== SECTION CLUBS ==========
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            sliver: SliverToBoxAdapter(
              child: _buildLuxurySectionHeader("Clubs", "Découvrez nos clubs d'excellence", isDarkMode),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLuxuryClubCard(clubs[index], isDarkMode, context),
                childCount: clubs.length,
              ),
            ),
          ),

          // ========== SECTION SPORTS ==========
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            sliver: SliverToBoxAdapter(
              child: _buildLuxurySectionHeader("Sports", "Performance et esprit d'équipe", isDarkMode),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLuxurySportCard(sports[index], isDarkMode, context),
                childCount: sports.length,
              ),
            ),
          ),

          // ========== SECTION ÉVÉNEMENTS ==========
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            sliver: SliverToBoxAdapter(
              child: _buildLuxurySectionHeader("Événements", "Ne manquez rien", isDarkMode),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLuxuryEventCard(events[index], isDarkMode, context),
                childCount: events.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildLuxurySectionHeader(String title, String subtitle, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [deepOrange, deepOrangeLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryClubCard(Map<String, dynamic> club, bool isDarkMode, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.grey.shade900, Colors.grey.shade800]
              : [Colors.white, Colors.grey.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: deepOrange.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: deepOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _showLuxuryDetails(context, club, isDarkMode),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icône premium
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [deepOrange, deepOrangeDark],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: deepOrange.withOpacity(0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        club['icon'],
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club['title'],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            club['subtitle'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(Icons.people_rounded, "24", "Membres"),
                    _buildStat(Icons.access_time_rounded, club['schedule'].split(' ')[0], "Horaire"),
                    _buildStat(Icons.star_rounded, "4.8", "Note"),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Badges
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: club['tags'].map<Widget>((tag) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: deepOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Lien détails
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Voir détails",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: deepOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: deepOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: deepOrange,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxurySportCard(Map<String, dynamic> sport, bool isDarkMode, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            deepOrange,
            deepOrangeLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: deepOrange.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _showLuxuryDetails(context, sport, isDarkMode),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sport['title'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sport['subtitle'],
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            sport['schedule'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            sport['lieu'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sport['icon'],
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryEventCard(Map<String, dynamic> event, bool isDarkMode, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: deepOrange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Fond avec image simulée
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    deepOrange.withOpacity(0.8),
                    deepOrangeDark,
                  ],
                ),
              ),
            ),
            
            // Overlay
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Contenu
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['subtitle'],
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                event['date'],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                event['lieu'],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Icône flottante
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event['icon'],
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: deepOrange, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  void _showLuxuryDetails(BuildContext context, Map<String, dynamic> item, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: deepOrange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      item['title'],
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Sous-titre
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        item['subtitle'],
                        style: TextStyle(
                          color: deepOrange,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Description
                    Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Informations
                    _buildLuxuryInfoTile(
                      Icons.access_time_rounded,
                      "Horaire",
                      item['schedule'],
                      isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    _buildLuxuryInfoTile(
                      Icons.location_on_rounded,
                      "Lieu",
                      item['lieu'],
                      isDarkMode,
                    ),
                    if (item.containsKey('responsable'))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildLuxuryInfoTile(
                          Icons.person_rounded,
                          "Responsable",
                          item['responsable'],
                          isDarkMode,
                        ),
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Bouton
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [deepOrange, deepOrangeLight],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: deepOrange.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxuryInfoTile(IconData icon, String label, String value, bool isDarkMode) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: deepOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: deepOrange, size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Données enrichies
  final List<Map<String, dynamic>> clubs = const [
    {
      'title': 'Club Scientifique',
      'subtitle': '🔬 Innovation & Découverte',
      'description': 'Rejoignez l\'élite scientifique du lycée ! Expériences en laboratoire de pointe, projets de recherche encadrés par des professionnels, et participation aux olympiades nationales. Développez votre esprit critique et votre créativité dans un environnement stimulant.',
      'icon': Icons.science_rounded,
      'schedule': 'Mercredi 14h-17h',
      'lieu': 'Laboratoire de pointe',
      'responsable': 'Dr. Diallo',
      'tags': ['Chimie', 'Physique', 'Biologie', 'Recherche'],
    },
    {
      'title': 'Club Informatique',
      'subtitle': '💻 Code • IA • Robotique',
      'description': 'Plongez dans l\'univers du numérique ! Apprenez à coder avec des experts, construisez des robots intelligents, explorez l\'intelligence artificielle et préparez-vous aux métiers de demain. Projets concrets et hackathons.',
      'icon': Icons.computer_rounded,
      'schedule': 'Mardi & Jeudi 15h-18h',
      'lieu': 'Labo numérique',
      'responsable': 'Mme Touré',
      'tags': ['Python', 'IA', 'Arduino', 'Web'],
    },
    {
      'title': 'Club Littéraire',
      'subtitle': '📚 Création & Expression',
      'description': 'Exprimez votre talent ! Ateliers d\'écriture avec des auteurs reconnus, publication dans le journal du lycée, organisation de concours de poésie et rencontres littéraires. Développez votre style et votre sens critique.',
      'icon': Icons.menu_book_rounded,
      'schedule': 'Vendredi 15h-18h',
      'lieu': 'Bibliothèque',
      'responsable': 'Mme Koné',
      'tags': ['Écriture', 'Poésie', 'Débat', 'Journal'],
    },
  ];

  final List<Map<String, dynamic>> sports = const [
    {
      'title': 'Football',
      'subtitle': '⚽ Excellence & Performance',
      'description': 'Entraînements intensifs avec des coachs diplômés, préparation physique de haut niveau, participation aux championnats régionaux et nationaux. Développez votre technique, votre condition physique et votre esprit d\'équipe.',
      'icon': Icons.sports_soccer_rounded,
      'schedule': 'Lun/Mer 16h-18h',
      'lieu': 'Stade',
      'responsable': 'M. Traoré',
    },
    {
      'title': 'Basket-ball',
      'subtitle': '🏀 Dribble • Tir • Stratégie',
      'description': 'Perfectionnez votre jeu avec des exercices techniques avancés, apprenez les systèmes de jeu professionnels et participez aux tournois inter-lycées. Ambiance compétitive et esprit d\'équipe.',
      'icon': Icons.sports_basketball_rounded,
      'schedule': 'Mar/Jeu 16h-18h',
      'lieu': 'Gymnase',
      'responsable': 'M. Coulibaly',
    },
  ];

  final List<Map<String, dynamic>> events = const [
    {
      'title': 'Journée Culturelle',
      'subtitle': '🎨 Art • Musique • Danse',
      'description': 'Une journée exceptionnelle dédiée à la créativité : expositions d\'art, concerts live, représentations théâtrales, danses traditionnelles et spectacles de rue. Célébrons ensemble la diversité culturelle.',
      'icon': Icons.palette_rounded,
      'date': '15 Décembre 2024',
      'lieu': 'Espace polyvalent',
    },
    {
      'title': 'Fête de la Science',
      'subtitle': '🔬 Ateliers • Conférences',
      'description': 'Explorez les sciences à travers des ateliers interactifs, des conférences passionnantes et des démonstrations spectaculaires. Rencontrez des chercheurs et découvrez les dernières innovations.',
      'icon': Icons.biotech_rounded,
      'date': '20-25 Novembre',
      'lieu': 'Hall scientifique',
    },
    {
      'title': 'Compétitions Inter-lycées',
      'subtitle': '🏆 Excellence & Dépassement',
      'description': 'Affrontez les meilleurs ! Tournois sportifs, concours académiques, challenges artistiques. Représentez votre lycée et visez la victoire dans une ambiance électrique.',
      'icon': Icons.emoji_events_rounded,
      'date': 'Mars 2025',
      'lieu': 'Plusieurs sites',
    },
  ];
}