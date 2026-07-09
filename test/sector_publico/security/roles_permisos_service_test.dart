/// Pruebas unitarias del camino normativo duro - Fase 0: Seguridad
/// Validaciones marcadas como "✅ Implementada (Dura)"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merka_erp/sector_publico/security/roles_permisos_service.dart';

void main() {
  late RolesPermisosService rolesService;

  setUp(() {
    rolesService = RolesPermisosService();
  });

  group('Validaciones Normativas Duras - Fase 0', () {
    test('NO debe permitir que tesorero apruebe sus propios pagos', () {
      // Arrange
      final usuarioId = 'usuario-tesorero';
      final rol = RolUsuario.tesorero;
      final pagoId = 'pago-001';
      final pagoUsuarioId = 'usuario-tesorero'; // El pago es del mismo usuario

      // Act & Assert
      expect(
        () => rolesService.validarAprobacionPago(
          usuarioId: usuarioId,
          rol: rol,
          pagoId: pagoId,
          pagoUsuarioId: pagoUsuarioId,
        ),
        throwsException,
      );
    });

    test('NO debe permitir que contador expida CDP/RP de sus propias transacciones', () {
      // Arrange
      final usuarioId = 'usuario-contador';
      final rol = RolUsuario.contador;
      final transaccionId = 'transaccion-001';
      final transaccionUsuarioId = 'usuario-contador'; // La transacción es del mismo usuario

      // Act & Assert
      expect(
        () => rolesService.validarExpedicionCDPRP(
          usuarioId: usuarioId,
          rol: rol,
          transaccionId: transaccionId,
          transaccionUsuarioId: transaccionUsuarioId,
        ),
        throwsException,
      );
    });

    test('NO debe permitir que secretario de hacienda apruebe sus propias obligaciones', () {
      // Arrange
      final usuarioId = 'usuario-secretario';
      final rol = RolUsuario.secretarioHacienda;
      final obligacionId = 'obligacion-001';
      final obligacionUsuarioId = 'usuario-secretario'; // La obligación es del mismo usuario

      // Act & Assert
      expect(
        () => rolesService.validarAprobacionObligacion(
          usuarioId: usuarioId,
          rol: rol,
          obligacionId: obligacionId,
          obligacionUsuarioId: obligacionUsuarioId,
        ),
        throwsException,
      );
    });

    test('Debe permitir que tesorero apruebe pagos de otros usuarios', () {
      // Arrange
      final usuarioId = 'usuario-tesorero';
      final rol = RolUsuario.tesorero;
      final pagoId = 'pago-001';
      final pagoUsuarioId = 'usuario-otro'; // El pago es de otro usuario

      // Act & Assert
      expect(
        () => rolesService.validarAprobacionPago(
          usuarioId: usuarioId,
          rol: rol,
          pagoId: pagoId,
          pagoUsuarioId: pagoUsuarioId,
        ),
        returnsNormally,
      );
    });

    test('Debe verificar que usuario tenga permiso para acción específica', () {
      // Arrange
      final rol = RolUsuario.tesorero;
      final accion = 'aprobar_pago';

      // Act
      final tienePermiso = rolesService.tienePermiso(rol: rol, accion: accion);

      // Assert
      expect(tienePermiso, isTrue);
    });

    test('NO debe permitir acción si usuario no tiene permiso', () {
      // Arrange
      final rol = RolUsuario.auditor;
      final accion = 'aprobar_pago'; // Auditor no puede aprobar pagos

      // Act
      final tienePermiso = rolesService.tienePermiso(rol: rol, accion: accion);

      // Assert
      expect(tienePermiso, isFalse);
    });
  });
}
