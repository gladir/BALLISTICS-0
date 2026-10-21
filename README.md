# BALLISTICS-0
Suite de commandes écrites en Turbo Pascal ou Free Pascal pour les calculs de balistique.

Aperçu de la commande CHAIRGUN :

<img width="641" height="481" alt="image" src="https://github.com/user-attachments/assets/af0fd9a6-1c74-41ec-b5c5-e65ec92b67cf" />

<h2>Liste des fichiers</h2>

Voici la liste des différentes commandes proposées dans BALLISTICS-0 :

<table>
  <tr>
    <th>Nom</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><b>BALISTIC.PAS</b></td>
    <td>Cette commande permet de calculer des trajectoires, des vitesses, des énergies, des portées, des tableaux balistiques et des conditions atmosphériques en ligne de commande.</td>
  </tr>
  <tr>
    <td><b>CHAIRGUN.PAS</b></td>
    <td>Cette commande est une application graphique inspirée de ChairGun, avec des menus déroulants en français, des courbes balistiques, un tableau, des champs modifiables et des réticules.</td>
  </tr>
</table>

<h2>Remarques</h2>

<ul>
  <li><b>BALISTIC.PAS</b> : les sous-commandes disponibles sont <code>TRAJECTORY</code>, <code>VELOCITY</code>, <code>ENERGY</code>, <code>RANGE</code>, <code>TABLE</code> et <code>ATMOSPHERE</code>. Afficher les paramètres avec <code>BALISTIC /HELP</code>. Les commandes <code>TABLE</code> et <code>TRAJECTORY</code> acceptent les formats TEXT, CSV et JSON. Les tableaux sont limités à 10 001 lignes régulières ; TRAJECTORY ajoute le point d'impact si nécessaire. L'option <code>RANGE /OPTIMIZE</code> recherche la portée maximale par pas de 0,1° entre 0,1° et 89,9°.</li>
  <li><b>Unités de BALISTIC</b> : masses en kg (10 g s'écrit <code>/MASS:0.010</code>), distances en m, vitesses en m/s, diamètre en mm, angles en degrés, pression en hPa et température en °C. Le paramètre <code>/ALT</code> indique l'altitude du terrain au-dessus de la mer. La hauteur de vol est relative au point de lancement ; le calcul s'arrête au retour à cette hauteur. Une distance au-delà de l'impact produit une erreur (code 1). Un angle de zéro donne une portée nulle.</li>
  <li><b>Modèle de BALISTIC</b> : intégration en deux dimensions par Runge-Kutta d'ordre 4, avec gravité constante et traînée quadratique (<code>Cd = 0.30 / BC</code>). La densité reste constante pendant le vol. STANDARD, ISA et ICAO utilisent la même approximation troposphérique de 0 à 11 000 m. CUSTOM accepte température, pression et humidité ; les valeurs omises proviennent de l'atmosphère standard. VACUUM annule la traînée. Le vent est projeté dans le plan du tir, sans dérive latérale. Les paramètres atmosphériques peuvent être passés aux commandes de vol et ne sont pas conservés entre les appels.</li>
  <li><b>CHAIRGUN.PAS</b> : interface VGA 640×480 utilisable à la souris et au clavier. Courbes cochables pour les zéros de 10, 20, 30 et 50 m ; la courbe rouge correspond au zéro saisi. Graphiques de trajectoire, vitesse, énergie, dérive et temps de vol ; zone utile ; réticules Mil-Dot, demi Mil-Dot et duplex (grossissement de référence 10×). Outils de calcul du zéro optimal, d'estimation de distance et d'ajustement du BC par vitesse mesurée. La masse se saisit en grammes et la hauteur de lunette en centimètres.</li>
  <li><b>Commandes de CHAIRGUN</b> : <code>CHAIRGUN /?</code> affiche l'aide en console. Dans l'interface, F10 ouvre les menus ; les flèches et Entrée permettent de les parcourir. Cliquer sur un champ pour le modifier, ou le sélectionner avec Tab puis appuyer sur Entrée. Retour arrière efface la valeur existante. Les touches 1 à 4 cochent les courbes ; PgHaut/PgBas font défiler le tableau. F1 affiche l'aide et Échap ferme le menu, puis quitte l'application.</li>
  <li><b>Fichiers de CHAIRGUN</b> : les profils texte enregistrent les 16 champs balistiques, sans les préférences d'affichage. L'export CSV contient distance, point d'impact, corrections signées en clics et mils, chute, vitesse, énergie, temps de vol et dérive. Il utilise le point décimal et le point-virgule comme séparateur.</li>
  <li><b>Modèle de CHAIRGUN</b> : traînée effective (<code>Cd = 0.30 * 0.021 / BC</code>), densité calculée à partir de la pression et de la température, vitesse décroissante exponentiellement avec la distance et chute calculée à partir du temps de vol. La gravité est projetée selon l'inclinaison ; la dérive est estimée par le retard de vol. Les combinaisons donnant <code>k * 500 &gt; 12</code> sont refusées pour borner le domaine numérique. Cette application autonome ne reproduit pas toutes les fonctions de ChairGun, sa bibliothèque de projectiles ou ses réticules propriétaires ; elle ne propose pas d'impression native.</li>
  <li><b>Limites des calculs</b> : les deux programmes utilisent des modèles simplifiés et différents. Leurs coefficients BC ne correspondent pas aux tables G1/G7 et leurs résultats ne sont pas équivalents à ceux du moteur propriétaire Hawke.</li>
  <li><b>Vérifications</b> : <code>CHAIRGUN /TEST</code> contrôle sans fenêtre le zéro, la hauteur de lunette, la décélération, le temps de vol, le signe de la dérive, les bornes des champs et l'optimisation du zéro. Le code de sortie est 0 en cas de succès.</li>
</ul>

<h2>Compilation</h2>

Compiler la commande désirée avec Free Pascal :

<pre><b>fpc</b> -Mtp BALISTIC.PAS
<b>fpc</b> -Mtp CHAIRGUN.PAS</pre>

Compiler avec Turbo Pascal :

<pre><b>tpc</b> BALISTIC.PAS
<b>tpc</b> CHAIRGUN.PAS</pre>

Les deux programmes ont été compilés avec Turbo Pascal ; les exécutables 16 bits se trouvent dans le répertoire <code>BIN16</code>.

CHAIRGUN utilise les unités <b>PtcGraph</b>, <b>PtcCrt</b> et <b>PtcMouse</b> sous Free Pascal. Sous Turbo Pascal, il utilise Crt, Graph et Dos, avec un pilote BGI et un pilote souris DOS.

<h2>Exemples d'utilisation</h2>

<pre>BALISTIC ENERGY /VELOCITY:800 /MASS:0.010
BALISTIC TABLE /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010 /END:1000 /FORMAT:CSV
BALISTIC RANGE /V0:100 /ATM:VACUUM /OPTIMIZE
BALISTIC ATMOSPHERE /MODEL:CUSTOM /ALT:1000 /TEMP:15 /PRESSURE:898.7 /HUMIDITY:50
CHAIRGUN /?
CHAIRGUN</pre>
