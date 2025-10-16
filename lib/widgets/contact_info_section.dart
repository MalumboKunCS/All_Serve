import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';
import '../models/provider.dart' as app_provider;
import '../theme/app_theme.dart';

class ContactInfoSection extends StatelessWidget {
  final app_provider.Service service;

  const ContactInfoSection({
    super.key,
    required this.service,
  });

  Future<void> _launchURL(BuildContext context, String url, String type) async {
    try {
      final uri = Uri.parse(url);
      AppLogger.debug('Attempting to launch $type: $url');
      
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        throw Exception('Cannot launch $type');
      }
      
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      AppLogger.info('Successfully launched $type for service: ${service.title}');
    } catch (e) {
      AppLogger.error('Error launching $type: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $type. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactInfo = service.contactInfo;

    // Safety check
    if (contactInfo == null || contactInfo.isEmpty) {
      AppLogger.warning('No contact info available for service: ${service.serviceId}');
      return Card(
        margin: const EdgeInsets.all(16),
        color: AppTheme.cardDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 8),
              Text(
                'Contact information not available',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_phone, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  'Contact Provider',
                  style: AppTheme.heading3.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap any option below to contact the provider directly',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone
            if (contactInfo['phone'] != null && contactInfo['phone'].toString().isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.phone,
                iconColor: AppTheme.success,
                title: 'Call Provider',
                subtitle: contactInfo['phone'],
                onTap: () => _launchURL(
                  context,
                  'tel:${contactInfo['phone']}',
                  'phone',
                ),
              ),
            
            // WhatsApp
            if (contactInfo['whatsapp'] != null && contactInfo['whatsapp'].toString().isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.chat,
                iconColor: const Color(0xFF25D366), // WhatsApp green
                title: 'Chat on WhatsApp',
                subtitle: contactInfo['whatsapp'],
                onTap: () => _launchURL(
                  context,
                  'https://wa.me/${contactInfo['whatsapp']!.toString().replaceAll('+', '')}',
                  'WhatsApp',
                ),
              ),
            
            // Email
            if (contactInfo['email'] != null && contactInfo['email'].toString().isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.email,
                iconColor: AppTheme.info,
                title: 'Send Email',
                subtitle: contactInfo['email'],
                onTap: () => _launchURL(
                  context,
                  'mailto:${contactInfo['email']}',
                  'email',
                ),
              ),
            
            // Website
            if (contactInfo['website'] != null && contactInfo['website'].toString().isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.language,
                iconColor: AppTheme.warning,
                title: 'Visit Website',
                subtitle: contactInfo['website'],
                onTap: () => _launchURL(
                  context,
                  contactInfo['website'],
                  'website',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.textTertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios, 
                size: 16, 
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
