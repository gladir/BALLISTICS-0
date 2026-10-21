# BALLISTICS-0
Suite de commandes écrites en Turbo Pascal ou Free Pascal pour les calculs de balistique.

Aperçu de la commande CHAIRGUN :

<img width="641" height="481" alt="image" src="https://github.com/user-attachments/assets/af0fd9a6-1c74-41ec-b5c5-e65ec92b67cf" />

Aperçu de la commande COMSOL : 

<img width="639" height="480" alt="image" src="https://github.com/user-attachments/assets/3af0335e-cbca-4e37-9caf-c34c9b1639fe" />

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
  <tr>
    <td><b>COMSOL.PAS</b></td>
    <td>Cette commande propose une interface graphique inspirée de COMSOL, avec un arbre de modèle, des réglages, des menus français, un maillage et un solveur stationnaire 2D de température ou de potentiel électrique.</td>
  </tr>
</table>

<h2>Remarques</h2>

<ul>
  <li><b>COMSOL.PAS</b> : lancement graphique avec <code>COMSOL</code> ; aide avec <code>COMSOL /?</code>. Arbre du modèle à gauche, réglages modifiables au centre, géométrie, maillage et résultats à droite. F10 ouvre les menus, F5 calcule, Tab sélectionne un paramètre et Entrée le modifie. Échap annule un calcul interactif ou ferme le menu puis l'application. Export CSV des valeurs et flux aux nœuds intérieurs.</li>
  <li><b>Solveur autonome COMSOL</b> : différences finies sur un rectangle homogène, 4 à 40 subdivisions par axe, équation stationnaire <code>-div(k grad u) = source</code>, quatre conditions de Dirichlet constantes. Physique 0 : conduction thermique (K, W/mK, W/m³) ; physique 1 : potentiel électrique (V, S/m, A/m³). La convergence est mesurée par la variation maximale entre itérations ; elle est signalée séparément de la présence d'une solution. Les fichiers texte <code>.csm</code> enregistrent les paramètres, l'état du maillage et la solution. Ce format est propre au programme et n'est pas un format MPH.</li>
  <li><b>Paramètres de COMSOL</b> : <code>-inputfile</code>, <code>-outputfile</code>, <code>-study</code> (std1), <code>-job</code> (sol1), <code>-methodcall</code> (reset, mesh, solve), <code>-batchlog</code>, <code>-batchlogout</code>, <code>-alivetime</code>, <code>-checklicense</code>, <code>-clearmesh</code>, <code>-clearsolution</code> (alias -clearsol), <code>-graphics</code>, <code>-nosave</code>, <code>-paramfile</code>, <code>-pname</code>, <code>-plist</code>, <code>-pindex</code> et <code>-cancel</code>. En mode autonome, -paramfile lit des lignes nom=valeur ; -pname et -plist associent des listes séparées par des virgules, sans balayage. -pindex sélectionne les lignes de paramètres non vides et non commentées, à partir de 1. -cancel annule l'exécution courante avant calcul, sans arrêter un autre processus. La suppression du maillage ou de la solution précède le recalcul. Codes de sortie : 0 succès, 1 erreur, 2 annulation préalable, 3 non-convergence en mode batch.</li>
  <li><b>Modèles MPH et classes COMSOL</b> : ils nécessitent le moteur officiel installé. Définir la variable d'environnement <code>COMSOL_BATCH</code> avec le chemin de <code>comsolbatch.exe</code>, puis employer <code>COMSOL -inputfile modele.mph</code> ou le menu Fichier, Exécuter MPH externe. Les options de ligne de commande sont transmises au moteur et son code de sortie est conservé. Le menu ferme l'interface avant de lancer ce moteur. La longueur totale des arguments externes est limitée à 240 caractères pour la compatibilité Turbo Pascal. Le programme ne décode pas les modèles MPH dans son propre arbre et n'exécute pas les classes Java lui-même. -checklicense sur un CSM indique qu'aucune licence COMSOL n'est nécessaire ; sur un MPH, la demande est transmise au moteur officiel.</li>
  <li><b>Limites de COMSOL.PAS</b> : application autonome inspirée de l'interface COMSOL, sans équivalence avec l'ensemble de ses modules multiphysiques, son moteur éléments finis, ses géométries 3D ou son éditeur de méthodes. Compilation Free Pascal vérifiée ; cette nouvelle commande reste à compiler sous Turbo Pascal. <code>COMSOL /TEST</code> vérifie un champ constant, une source de Poisson, le résidu de l'équation discrète, la symétrie et la détection de non-convergence. Documentation du format MPH et des options externes : <a href="https://www.comsol.com/support/learning-center/article/supported-file-formats-76161">formats COMSOL</a> et <a href="https://doc.comsol.com/6.3/doc/com.comsol.help.comsol/comsol_ref_running.38.31.html">commandes COMSOL sous Windows</a>.</li>
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
<b>fpc</b> -Mtp CHAIRGUN.PAS
<b>fpc</b> -Mtp COMSOL.PAS</pre>

Compiler avec Turbo Pascal :

<pre><b>tpc</b> BALISTIC.PAS
<b>tpc</b> CHAIRGUN.PAS
<b>tpc</b> COMSOL.PAS</pre>

BALISTIC et CHAIRGUN ont été compilés avec Turbo Pascal ; leurs exécutables 16 bits se trouvent dans le répertoire <code>BIN16</code>.

CHAIRGUN et COMSOL utilisent les unités <b>PtcGraph</b>, <b>PtcCrt</b> et <b>PtcMouse</b> sous Free Pascal. Sous Turbo Pascal, ils utilisent Crt, Graph et Dos, avec un pilote BGI et un pilote souris DOS.

<h2>Exemples d'utilisation</h2>

<pre>BALISTIC ENERGY /VELOCITY:800 /MASS:0.010
BALISTIC TABLE /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010 /END:1000 /FORMAT:CSV
BALISTIC RANGE /V0:100 /ATM:VACUUM /OPTIMIZE
BALISTIC ATMOSPHERE /MODEL:CUSTOM /ALT:1000 /TEMP:15 /PRESSURE:898.7 /HUMIDITY:50
CHAIRGUN /?
CHAIRGUN
COMSOL
COMSOL /?
COMSOL batch -pname gauche,droite,bas,haut -plist 350,300,300,300 -outputfile CHALEUR.CSM -batchlogout
COMSOL -inputfile CHALEUR.CSM -graphics -nosave
COMSOL -inputfile modele.mph -outputfile resultat.mph -study std1</pre>
