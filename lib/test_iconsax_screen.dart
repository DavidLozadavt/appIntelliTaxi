import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class TestIconsaxScreen extends StatelessWidget {
  const TestIconsaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iconsax - Iconos Profesionales'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Negocios & Finanzas
          _buildSection(
            'Negocios & Finanzas',
            [
              _IconItem(Iconsax.briefcase_copy, 'Briefcase'),
              _IconItem(Iconsax.money_copy, 'Money'),
              _IconItem(Iconsax.chart_copy, 'Chart'),
              _IconItem(Iconsax.trend_up_copy, 'Trend Up'),
              _IconItem(Iconsax.wallet_copy, 'Wallet'),
              _IconItem(Iconsax.card_copy, 'Card'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Usuarios & Personas
          _buildSection(
            'Usuarios & Personas',
            [
              _IconItem(Iconsax.user_copy, 'User'),
              _IconItem(Iconsax.profile_2user_copy, 'Users'),
              _IconItem(Iconsax.people_copy, 'People'),
              _IconItem(Iconsax.user_octagon_copy, 'User Badge'),
              _IconItem(Iconsax.user_square_copy, 'User Square'),
              _IconItem(Iconsax.profile_circle_copy, 'Profile'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Documentos & Archivos
          _buildSection(
            'Documentos & Archivos',
            [
              _IconItem(Iconsax.document_copy, 'Document'),
              _IconItem(Iconsax.folder_copy, 'Folder'),
              _IconItem(Iconsax.note_copy, 'Note'),
              _IconItem(Iconsax.clipboard_copy, 'Clipboard'),
              _IconItem(Iconsax.archive_copy, 'Archive'),
              _IconItem(Iconsax.document_text_copy, 'Doc Text'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Comunicación
          _buildSection(
            'Comunicación',
            [
              _IconItem(Iconsax.message_copy, 'Message'),
              _IconItem(Iconsax.messages_copy, 'Messages'),
              _IconItem(Iconsax.sms_copy, 'SMS'),
              _IconItem(Iconsax.call_copy, 'Call'),
              _IconItem(Iconsax.notification_copy, 'Notification'),
              _IconItem(Iconsax.send_copy, 'Send'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Acciones
          _buildSection(
            'Acciones',
            [
              _IconItem(Iconsax.add_copy, 'Add'),
              _IconItem(Iconsax.edit_copy, 'Edit'),
              _IconItem(Iconsax.trash_copy, 'Delete'),
              _IconItem(Iconsax.save_2_copy, 'Save'),
              _IconItem(Iconsax.search_normal_copy, 'Search'),
              _IconItem(Iconsax.filter_copy, 'Filter'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Navegación
          _buildSection(
            'Navegación',
            [
              _IconItem(Iconsax.home_copy, 'Home'),
              _IconItem(Iconsax.setting_2_copy, 'Settings'),
              _IconItem(Iconsax.menu_copy, 'Menu'),
              _IconItem(Iconsax.arrow_left_copy, 'Back'),
              _IconItem(Iconsax.arrow_right_copy, 'Forward'),
              _IconItem(Iconsax.more_copy, 'More'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Seguridad
          _buildSection(
            'Seguridad',
            [
              _IconItem(Iconsax.lock_copy, 'Lock'),
              _IconItem(Iconsax.shield_tick_copy, 'Shield'),
              _IconItem(Iconsax.key_copy, 'Key'),
              _IconItem(Iconsax.scan_copy, 'Scan'),
              _IconItem(Iconsax.eye_copy, 'View'),
              _IconItem(Iconsax.eye_slash_copy, 'Hide'),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Tiempo & Calendario
          _buildSection(
            'Tiempo & Calendario',
            [
              _IconItem(Iconsax.calendar_copy, 'Calendar'),
              _IconItem(Iconsax.clock_copy, 'Clock'),
              _IconItem(Iconsax.timer_copy, 'Timer'),
              _IconItem(Iconsax.task_square_copy, 'Task'),
              _IconItem(Iconsax.tick_square_copy, 'Check'),
              _IconItem(Iconsax.close_square_copy, 'Close'),
            ],
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, List<_IconItem> icons, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            final iconItem = icons[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade800.withOpacity(0.5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconItem.icon,
                    size: 32,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    iconItem.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IconItem {
  final IconData icon;
  final String name;

  _IconItem(this.icon, this.name);
}
