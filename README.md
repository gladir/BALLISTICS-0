# BALLISTICS-0
Suite de commande écrit en Turbo Pascal/Free Pascal sur la balistique

`BALISTIC.PAS` fournit `TRAJECTORY`, `VELOCITY`, `ENERGY`, `RANGE`,
`TABLE` et `ATMOSPHERE`. Afficher toutes les options avec `BALISTIC /HELP`.

Compilation compatible avec le mode Turbo Pascal de Free Pascal :

```text
fpc -Mtp BALISTIC.PAS
BALISTIC ENERGY /VELOCITY:800 /MASS:0.010
BALISTIC TABLE /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010 /END:1000 /FORMAT:CSV
BALISTIC RANGE /V0:100 /ATM:VACUUM /OPTIMIZE
BALISTIC ATMOSPHERE /MODEL:CUSTOM /ALT:1000 /TEMP:15 /PRESSURE:898.7 /HUMIDITY:50
```

Toutes les masses sont en **kg**, y compris pour les trajectoires :
10 g s'écrit `/MASS:0.010`. Distances en m, vitesses en m/s, diamètre
en mm, angles en degrés, pression en hPa, température en °C.
`/ALT` est l'altitude du terrain au-dessus de la mer. La hauteur affichée
est relative au point de lancement ; le vol se termine au retour à cette
hauteur. Une distance au-delà de l'impact produit une erreur (code 1).
Un angle de zéro donne donc une portée nulle.

Le modèle pédagogique intègre un mouvement en deux dimensions avec
gravité constante et traînée quadratique par Runge-Kutta d'ordre 4.
`BC` est ici un facteur simplifié : `Cd = 0.30 / BC`, puis
`force = 0.5 * densité * Cd * surface * vitesse_relative²`.
Il ne représente pas un coefficient G1/G7 et ne reproduit pas les valeurs
illustratives de la demande ni un moteur professionnel. La densité est
constante pendant le vol et calculée à l'altitude du terrain.
STANDARD, ISA et ICAO désignent la même approximation troposphérique
(0 à 11 000 m). CUSTOM accepte température, pression et humidité ;
les valeurs omises viennent de l'atmosphère standard. VACUUM annule la
traînée. Le vent est projeté dans le plan du tir, sans dérive latérale.
Les paramètres atmosphériques peuvent aussi être passés aux commandes
de vol et ne sont pas enregistrés entre les appels.

TABLE et TRAJECTORY acceptent TEXT, CSV et JSON. Les tables sont limitées
à 10 001 lignes régulières ; TRAJECTORY ajoute le point d'impact si nécessaire.
RANGE /OPTIMIZE examine les angles de 0,1° à 89,9° par pas de 0,1°.
Les limites de simulation sont indiquées dans l'aide.

Après compilation, lancer les vérifications numériques sous PowerShell :

```powershell
.\TEST-BALISTIC.ps1
```
