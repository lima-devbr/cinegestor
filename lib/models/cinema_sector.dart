import 'package:flutter/material.dart';

class CinemaSector {
  final String id;
  final String name;
  final IconData icon;
  final String shortCode;
  final String description;

  const CinemaSector({
    required this.id,
    required this.name,
    required this.icon,
    required this.shortCode,
    required this.description,
  });

  static const List<CinemaSector> commonSectors = [
    CinemaSector(
      id: 'setor_bomboniere',
      name: 'Bomboniere',
      icon: Icons.fastfood_rounded,
      shortCode: 'BOMB',
      description: 'Pipoca, estufas, geladeiras, caixas e balcão',
    ),
    CinemaSector(
      id: 'setor_bilheteria',
      name: 'Bilheteria / Totens',
      icon: Icons.confirmation_number_rounded,
      shortCode: 'BILH',
      description: 'Terminais de autoatendimento, guichês e monitores',
    ),
    CinemaSector(
      id: 'setor_foyer',
      name: 'Foyer / Corredores',
      icon: Icons.apartment_rounded,
      shortCode: 'FOYR',
      description: 'Hall de entrada, corredores de acesso e displays',
    ),
    CinemaSector(
      id: 'setor_banheiro_f',
      name: 'Banheiro Feminino',
      icon: Icons.woman_rounded,
      shortCode: 'WC-F',
      description: 'Cabines, pias, espelhos, descargas e secadores',
    ),
    CinemaSector(
      id: 'setor_banheiro_m',
      name: 'Banheiro Masculino',
      icon: Icons.man_rounded,
      shortCode: 'WC-M',
      description: 'Cabines, mictórios, pias, espelhos e descargas',
    ),
    CinemaSector(
      id: 'setor_gerencia',
      name: 'Gerência / Escritório',
      icon: Icons.business_center_rounded,
      shortCode: 'GER',
      description: 'Administração, cofres e computadores',
    ),
    CinemaSector(
      id: 'setor_area_funcionarios',
      name: 'Área Funcionários (Copa/DML)',
      icon: Icons.badge_rounded,
      shortCode: 'FUNC',
      description: 'Copa, vestiários, armários e depósito de limpeza (DML)',
    ),
    CinemaSector(
      id: 'setor_cabine_projecao',
      name: 'Cabine de Projeção',
      icon: Icons.videocam_rounded,
      shortCode: 'PROJ',
      description: 'Projetores, racks de áudio, servidores e exaustão',
    ),
  ];

  static CinemaSector? findById(String id) {
    for (final s in commonSectors) {
      if (s.id == id) return s;
    }
    return null;
  }
}
