# Historique

## [Unreleased]

- Adopte la déclaration `Result` unique : l’appel ordinaire rend la valeur
  ou arrête le programme sur erreur ; `try appel()` conserve le `Result`. Les
  anciens appels stockant un résultat et propagations deviennent explicites.
  Cette révision requiert la toolchain de développement avec cette sémantique
  de `try` ; sa publication doit coordonner les versions du compilateur et des
  packages.
  Les variantes récupérables `try_*` et wrappers directs de même signature
  sont réunis sous le nom ordinaire. Les variantes booléennes, optionnelles ou
  natives gardent leur contrat.
