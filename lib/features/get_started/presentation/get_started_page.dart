import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hellovietnam/app/router.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  static const String _backgroundImageUrl =
      'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/GetStarted/Vietnam.jpg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvR2V0U3RhcnRlZC9WaWV0bmFtLmpwZyIsImlhdCI6MTc3Mjg2ODcxOSwiZXhwIjoxODA0NDA0NzE5fQ.jB0W5diFtiHeYSrGAmNV051orO5sRER1gnqfIEm9LaI';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.network(
              _backgroundImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF1E6A88));
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0.45, 0.72, 1],
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.50),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'Explore Vietnam with',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      'HelloVietnam',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.smooch(
                        color: const Color(0xFFF3DF6B),
                        fontSize: 65,
                        fontWeight: FontWeight.w400,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Explore local culture, traditional food, and '
                      'meaningful travel experiences across Vietnam.\n'
                      'Let us guide you through every journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF92D5F8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Get Started'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
