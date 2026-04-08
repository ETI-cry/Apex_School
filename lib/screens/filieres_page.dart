import 'package:flutter/material.dart';

import 'filiere_detail_page.dart';

class FilieresPage extends StatelessWidget {
  const FilieresPage({super.key});

  // Données structurées des filières
  final List<Map<String, dynamic>> filieres = const [
    {
      'id': '1',
      'title': 'SCIENCES INFORMATIQUES',
      'tagline': 'Développement • IA • Cybersécurité',
      'description': 'Formation d\'excellence aux métiers du numérique et de l\'intelligence artificielle.',
      'color': Color(0xFF2563EB),
      'icon': Icons.code_rounded,
      'niveau': 'Première & Terminale',
      'matieres': [
        {'nom': 'Algorithmique avancée', 'coef': 4},
        {'nom': 'Intelligence Artificielle', 'coef': 5},
        {'nom': 'Cybersécurité', 'coef': 3},
        {'nom': 'Big Data', 'coef': 4},
        {'nom': 'Projet innovant', 'coef': 4},
      ],
      'debouches': ['Développeur Full-Stack', 'Data Scientist', 'Expert Cybersécurité', 'Architecte IA']
    },
    {
      'id': '2',
      'title': 'GESTION & COMMERCE',
      'tagline': 'Marketing • Finance • Management',
      'description': 'Parcours stratégique pour les futurs leaders du business et du management digital.',
      'color': Color(0xFF059669),
      'icon': Icons.trending_up_rounded,
      'niveau': 'Première & Terminale',
      'matieres': [
        {'nom': 'Marketing digital', 'coef': 4},
        {'nom': 'Finance d\'entreprise', 'coef': 4},
        {'nom': 'Management stratégique', 'coef': 3},
        {'nom': 'Négociation', 'coef': 3},
        {'nom': 'Business English', 'coef': 2},
      ],
      'debouches': ['Chef de produit', 'Analyste financier', 'Business Developer', 'Entrepreneur']
    },
    {
      'id': '3',
      'title': 'ÉLECTRONIQUE & ROBOTIQUE',
      'tagline': 'Circuits • Arduino • Automatisme',
      'description': 'Maîtrisez les technologies de demain : de la conception de circuits à la robotique intelligente.',
      'color': Color(0xFFDC2626),
      'icon': Icons.memory_rounded,
      'niveau': 'Première & Terminale',
      'matieres': [
        {'nom': 'Circuits logiques', 'coef': 4},
        {'nom': 'Programmation Arduino', 'coef': 5},
        {'nom': 'Automatismes', 'coef': 4},
        {'nom': 'IoT', 'coef': 3},
        {'nom': 'Projet robotique', 'coef': 4},
      ],
      'debouches': ['Ingénieur en robotique', 'Automaticien', 'Technicien supérieur', 'Intégrateur IoT']
    },
    {
      'id': '4',
      'title': 'SCIENCES DE LA VIE',
      'tagline': 'Biologie • Chimie • Santé',
      'description': 'Préparation aux carrières scientifiques et médicales d\'excellence.',
      'color': Color(0xFF7C3AED),
      'icon': Icons.biotech_rounded,
      'niveau': 'Première & Terminale',
      'matieres': [
        {'nom': 'Biologie moléculaire', 'coef': 5},
        {'nom': 'Chimie organique', 'coef': 4},
        {'nom': 'Physiologie', 'coef': 4},
        {'nom': 'Biochimie', 'coef': 4},
        {'nom': 'Anglais scientifique', 'coef': 2},
      ],
      'debouches': ['Médecine', 'Pharmacie', 'Recherche', 'Ingénieur en biotech']
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NOS FILIÈRES',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: filieres.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final filiere = filieres[index];
          return _FiliereTile(
            filiere: filiere,
            isDarkMode: isDarkMode,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => FiliereDetailPage(filiere: filiere),
                  transitionsBuilder: (_, animation, __, child) {
                    const begin = Offset(0.0, 0.05);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FiliereTile extends StatelessWidget {
  final Map<String, dynamic> filiere;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _FiliereTile({
    required this.filiere,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDarkMode 
                ? Colors.grey.shade800 
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + niveau
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (filiere['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    filiere['icon'],
                    color: filiere['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    filiere['niveau'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Titre
            Text(
              filiere['title'],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.2,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              filiere['tagline'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: filiere['color'],
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            Text(
              filiere['description'],
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            
            // Lien vers détails
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'VOIR LE PROGRAMME',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: filiere['color'],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: filiere['color'],
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}