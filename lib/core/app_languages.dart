/// Registro dos idiomas suportados pela interface (usados pelo teclado
/// virtual e pelas futuras traduções do app).
class AppLanguage {
  final String id;
  final String label;

  const AppLanguage(this.id, this.label);
}

const List<AppLanguage> appLanguages = [
  AppLanguage('pt-BR', 'Português'),
  AppLanguage('en-US', 'English'),
  AppLanguage('es-ES', 'Español'),
  AppLanguage('fr-FR', 'Français'),
  AppLanguage('de-DE', 'Deutsch'),
  AppLanguage('it-IT', 'Italiano'),
];

/// Retorna o idioma registrado por id, ou o padrão ('pt-BR') se desconhecido.
AppLanguage appLanguageById(String id) {
  for (final l in appLanguages) {
    if (l.id.toLowerCase() == id.toLowerCase()) return l;
  }
  return appLanguages.first;
}
