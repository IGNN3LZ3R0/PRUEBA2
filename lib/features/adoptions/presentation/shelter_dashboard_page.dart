import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/custom_button.dart';
import '../data/adoption_repository.dart';
import '../data/models.dart';

class ShelterDashboardPage extends StatefulWidget {
  const ShelterDashboardPage({super.key});

  @override
  State<ShelterDashboardPage> createState() => _ShelterDashboardPageState();
}

class _ShelterDashboardPageState extends State<ShelterDashboardPage> {
  final _adoptionRepo = AdoptionRepository();
  List<AdoptionRequestModel> _requests = [];
  bool _isLoading = true;
  String _selectedFilter = 'pendiente';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseClientManager.instance.userId;
      if (userId != null) {
        _requests = await _adoptionRepo.getRefugioRequests(userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<AdoptionRequestModel> get _filteredRequests {
    return _requests.where((r) => r.status == _selectedFilter).toList();
  }

  Future<void> _handleApprove(AdoptionRequestModel request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar Solicitud'),
        content: Text(
            '¿Aprobar la solicitud de ${request.adoptanteName} para adoptar a ${request.petName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.approved),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adoptionRepo.approveRequest(request.id, request.petId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Solicitud aprobada! La mascota ha sido adoptada.'),
              backgroundColor: AppTheme.approved,
            ),
          );
          _loadRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleReject(AdoptionRequestModel request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: Text('¿Rechazar la solicitud de ${request.adoptanteName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rejected),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adoptionRepo.rejectRequest(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud rechazada'),
              backgroundColor: AppTheme.rejected,
            ),
          );
          _loadRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Solicitudes'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Cargando solicitudes...')
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: Column(
                children: [
                  _buildFilterChips(),
                  Expanded(child: _buildRequestsList()),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _FilterChip(
            label: 'Pendientes',
            count: _requests.where((r) => r.isPending).length,
            isSelected: _selectedFilter == 'pendiente',
            color: AppTheme.pending,
            onTap: () => setState(() => _selectedFilter = 'pendiente'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Aprobadas',
            count: _requests.where((r) => r.isApproved).length,
            isSelected: _selectedFilter == 'aprobada',
            color: AppTheme.approved,
            onTap: () => setState(() => _selectedFilter = 'aprobada'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Rechazadas',
            count: _requests.where((r) => r.isRejected).length,
            isSelected: _selectedFilter == 'rechazada',
            color: AppTheme.rejected,
            onTap: () => setState(() => _selectedFilter = 'rechazada'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 80, color: AppTheme.textGrey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes ${_selectedFilter}s',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        return _RequestCard(
          request: _filteredRequests[index],
          onApprove:
              _selectedFilter == 'pendiente' ? _handleApprove : null,
          onReject: _selectedFilter == 'pendiente' ? _handleReject : null,
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.textGrey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AdoptionRequestModel request;
  final Function(AdoptionRequestModel)? onApprove;
  final Function(AdoptionRequestModel)? onReject;

  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.adoptanteName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quiere adoptar a ${request.petName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mensaje:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.message!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: AppTheme.textGrey.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(
                  request.getTimeAgo(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (onApprove != null && onReject != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Rechazar',
                      onPressed: () => onReject!(request),
                      backgroundColor: AppTheme.rejected,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Aprobar',
                      onPressed: () => onApprove!(request),
                      backgroundColor: AppTheme.approved,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}