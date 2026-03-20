import 'package:firebase_ai_sample/view/chat_screen.dart';
import 'package:firebase_ai_sample/view/story_generator_screen.dart';
import 'package:firebase_ai_sample/view/talk_to_ai_screen.dart';
import 'package:firebase_ai_sample/view/wallpaper_generator_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Welcome to the Future!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Explore what you can do with AI today.",
                style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 190, // Fixed height prevents RenderOverflow
                  ),
                  children: [
                    GridCard(
                      icon: Icons.auto_stories_rounded,
                      title: "Story Generator",
                      subtitle: "Magical bedtime stories for kids",
                      colors: const [Color(0xFFFF9A44), Color(0xFFFC6076)],
                      shadowColor: const Color(
                        0xFFFC6076,
                      ).withValues(alpha: 0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoryGeneratorScreen(),
                          ),
                        );
                      },
                    ),
                    GridCard(
                      icon: Icons.forum_rounded,
                      title: "Smart Chat",
                      subtitle: "Find solutions for any problem",
                      colors: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                      shadowColor: const Color(
                        0xFF4FACFE,
                      ).withValues(alpha: 0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                    ),
                    GridCard(
                      icon: Icons.wallpaper_rounded,
                      title: "Art & Wallpapers",
                      subtitle: "Create stunning custom visuals",
                      colors: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                      shadowColor: const Color(
                        0xFF43E97B,
                      ).withValues(alpha: 0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const WallpaperGeneratorScreen(),
                          ),
                        );
                      },
                    ),
                    GridCard(
                      icon: Icons.record_voice_over_rounded,
                      title: "Voice AI",
                      subtitle: "Talk directly to your AI assistant",
                      colors: const [Color(0xFFB19CD9), Color(0xFF9881CD)],
                      shadowColor: const Color(
                        0xFF9881CD,
                      ).withValues(alpha: 0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TalkToAiScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color shadowColor;
  final VoidCallback onTap;

  const GridCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  State<GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<GridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.shadowColor,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(widget.icon, size: 30, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
