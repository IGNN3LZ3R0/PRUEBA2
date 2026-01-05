import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

class SelectUserTypePage extends StatelessWidget {
  const SelectUserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              Text(
                AppStrings.whoAreYou,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                AppStrings.selectAccountType,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              
              const SizedBox(height: 40),
              
              // Card Adoptante
              _UserTypeCard(
                icon: Icons.home_outlined,
                title: AppStrings.adoptante,
                description: AppStrings.adoptanteDesc,
                color: AppTheme.primary,
                onTap: () => Navigator.pop(context, AppConstants.userTypeAdoptante),
              ),
              
              const SizedBox(height: 20),
              
              // Card Refugio
              _UserTypeCard(
                icon: Icons.business_outlined,
                title: AppStrings.refugio,
                description: AppStrings.refugioDesc,
                color: AppTheme.secondary,
                onTap: () => Navigator.pop(context, AppConstants.userTypeRefugio),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}