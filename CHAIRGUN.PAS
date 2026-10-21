{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/ballistics-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2) 
  @description: Modele autonome simplifie pour le calcul balistique, utilisant les unites SI.
  }
  

Program CHAIRGUN;

{ ChairGun libre - interface francaise, Turbo Pascal 7 / Free Pascal 3.2.
  Modele autonome simplifie, pas le moteur proprietaire Hawke/G1.
  Unites SI; masse saisie en grammes, hauteur en cm, correction en mils.
  /TEST execute les controles numeriques sans ouvrir de fenetre. }
{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

Uses
{$IFDEF FPC}
 Crt,PtcGraph,PtcCrt,PtcMouse,Dos
{$ELSE}
 Crt,Graph,Dos
{$ENDIF}
;

Const
 NF=16;
 Labels:Array[1..NF] Of String[20]=('Calibre mm','Masse g','Coefficient BC',
 'Vitesse m/s','Zero m','Lunette cm','Portee m','Pas tableau m',
 'Inclinaison deg','Vent km/h','Angle vent deg','Grossissement',
 'Clic MOA','Zone utile cm','Temperature C','Pression hPa');
 Defaults:Array[1..NF] Of real=(4.5,0.547,0.021,176,20,7.36,65,5,0,0,90,10,0.25,4,15,
 1013.25);
 Minima:Array[1..NF] Of real=(1,0.01,0.001,10,1,0,10,1,-80,0,-180,1,0.01,0.1,-50,100);
 Maxima:Array[1..NF] Of real=(30,100,2,1500,500,50,500,100,80,150,180,60,10,100,60,1200);
 Zeros:Array[1..4] Of integer=(10,20,30,50);
 Colors:Array[1..4] Of integer=(Blue,LightBlue,Green,Brown);
 Menus:Array[1..6] Of String[12]=('Fichier','Affichage','Graphiques','Reticule','Outils',
 'Aide');

Var
 P:Array[1..NF] Of real;
 Enabled:Array[1..4] Of boolean;
 Done,Grid,Zone,ShowRet:boolean;
 GraphKind,RetKind,TopRow,Selected,Menu,MenuRow:integer;
 MX,MY,MB,OldB:integer;
 Status:String;
 K:real;

Function F(V:real; N:integer):String;
Var
 S:String;
Begin
 Str(V:0:N,S); F:=S
End;

Function Rad(A:real):real;Begin
 Rad:=A*Pi/180
End;

Procedure Model;Begin
 { Effective Cd scaled by the user BC. This is deliberately NOT G1. }
 K:=0.5*(P[16]*100/(287.05*(P[15]+273.15)))*
 (0.30*0.021/P[3])*Pi*Sqr(P[1]/2000)/(P[2]/1000);
End;

Function TimeAt(X:real):real;Begin
 TimeAt:=(Exp(K*X)-1)/(K*P[4])
End;

Function DropAt(X:real):real;Begin
 DropAt:=4.903325*Sqr(TimeAt(X))*Cos(Rad(P[9]))
End;

Function POI(X,Z:real):real;Begin
 POI:=100*(-P[6]/100+(P[6]/100+DropAt(Z))*X/Z-DropAt(X))
End;

Function SpeedAt(X:real):real;Begin
 SpeedAt:=P[4]*Exp(-K*X)
End;

Function Drift(X:real):real;Begin
 Drift:=100*P[10]/3.6*Sin(Rad(P[11]))*(TimeAt(X)-X/P[4])
End;

Function Mils(X:real):real;Begin
 Mils:=-POI(X,P[5])*10/X
End;

Function Valid(I:integer; V:real):boolean;Begin
 Valid:=(V>=Minima[I]) And (V<=Maxima[I])
End;

Procedure ResetDefaults;
Var
 I:integer;
Begin
 For I:=1 To NF Do P[I]:=Defaults[I];
 For I:=1 To 4 Do Enabled[I]:=True;
 Grid:=True; Zone:=True; ShowRet:=True; GraphKind:=0; RetKind:=0;
 TopRow:=0; Selected:=4; Model;
End;
Procedure Mouse(Show:boolean);
{$IFNDEF FPC}

 Var
  R:Registers;
 {$ENDIF}
Begin
 {$IFDEF FPC}
  If Show Then PtcMouse.ShowMouse Else PtcMouse.HideMouse;
 {$ELSE}
  If Show Then R.AX:=1 Else R.AX:=2; Intr($33,R);
 {$ENDIF}
End;
Procedure Poll;
{$IFDEF FPC}

 Var
  X,Y,B:longint;
 {$ELSE}

 Var
  R:Registers;
 {$ENDIF}
Begin
 {$IFDEF FPC}
  PtcMouse.GetMouseState(X,Y,B); MX:=X; MY:=Y; MB:=B;
 {$ELSE}
  R.AX:=3; Intr($33,R); MX:=R.CX; MY:=R.DX; MB:=R.BX;
 {$ENDIF}
End;

Procedure Box(X1,Y1,X2,Y2,C:integer);Begin
 SetFillStyle(SolidFill,C); Bar(X1,Y1,X2,Y2)
End;

Procedure Txt(X,Y,C:integer; S:String);Begin
 SetColor(C); OutTextXY(X,Y,S)
End;

Function ItemCount(M:integer):integer;Begin
 Case M Of 1:ItemCount:=5; 2:ItemCount:=4; 3:ItemCount:=5;
 4:ItemCount:=3; 5:ItemCount:=3; Else ItemCount:=2
End
End;

Function Item(M,R:integer):String;Begin
 Item:='';
 Case M Of
 1:Case R Of 1:Item:='Nouveau';2:Item:='Ouvrir profil';3:Item:='Enregistrer profil';
 4:Item:='Exporter tableau CSV';5:Item:='Quitter';
End;
2:Case R Of 1:Item:='Grille';2:Item:='Zone utile';3:Item:='Afficher reticule';
4:Item:='Modifier un champ';
End;
3:Case R Of 1:Item:='Trajectoire (cm)';2:Item:='Vitesse (m/s)';3:Item:='Energie (J)';
4:Item:='Derive vent (cm)';5:Item:='Temps de vol (s)';
End;
4:Case R Of 1:Item:='Mil-Dot 6 points';2:Item:='Demi Mil-Dot';3:Item:='Duplex';
End;
5:Case R Of 1:Item:='Zero optimal';2:Item:='Mesurer le BC';3:Item:='Estimer distance';
End;
6:Case R Of 1:Item:='Commandes';2:Item:='Modele et limites';
End;
End;
End;

Procedure DrawReticle;
Var
 I,X,Y,CX,CY:integer;
 D:real;
Begin
 Box(4,302,253,454,White); Txt(8,306,Blue,'Reticule - '+F(P[12],1)+' x');
 CX:=126; CY:=373; SetColor(Black); Line(12,CY,244,CY); Line(CX,324,CX,447);
 If RetKind<2 Then
 For I:=-6 To 6 Do If I<>0 Then Begin
  D:=I*P[12]; If RetKind=1 Then D:=D/2;
  X:=CX+Round(D); Y:=CY+Round(D);
  If (X>12) And (X<244) Then FillEllipse(X,CY,2,2);
  If (Y>324) And (Y<447) Then FillEllipse(CX,Y,2,2);
 End;
 For I:=1 To 10 Do Begin
  D:=I*P[7]/10; D:=Mils(D)*P[12];
  If (D>-48) And (D<70) Then Y:=CY+Round(D) Else Y:=0;
  If (Y>325) And (Y<443) Then Begin
   Txt(CX+8,Y,Blue,F(I*P[7]/10,0)); SetColor(Red); Line(CX-4,Y,CX+4,Y);
  End;
 End;
End;

Function Curve(X,Z:real):real;Begin
 Case GraphKind Of
 0:Curve:=POI(X,Z);1:Curve:=SpeedAt(X);
 2:Curve:=P[2]/2000*Sqr(SpeedAt(X));3:Curve:=Drift(X);
 Else Curve:=TimeAt(X)
End
End;

Procedure Draw;
Var
 I,J,X,Y,PX,PY,YY,Rows,Idx:integer;
 D,V,Lo,Hi,Z:real;
 S:String;
Begin
 Mouse(False); ClearDevice;
 Box(0,0,639,19,LightGray);
 For I:=1 To 6 Do Txt((I-1)*105+4,6,Black,Menus[I]);
 For I:=1 To 4 Do Begin
  X:=(I-1)*160; Box(X,22,X+158,40,Colors[I]);
  If Enabled[I] Then S:='[X] ' Else S:='[ ] ';
  Txt(X+5,27,White,S+F(Zeros[I],0)+' m');
 End;
 For I:=1 To NF Do Begin
  X:=((I-1) Mod 4)*160; Y:=44+((I-1) Div 4)*30;
  Txt(X+3,Y,LightGray,Labels[I]);
  If I=Selected Then Box(X+1,Y+11,X+155,Y+26,Blue)
                Else Box(X+1,Y+11,X+155,Y+26,DarkGray);
  Txt(X+5,Y+15,White,F(P[I],3));
 End;
 Txt(4,170,White,' m    POI cm  clics  mils   m/s');
 Rows:=19; If ShowRet Then Rows:=9;
 For I:=0 To Rows-1 Do Begin
  D:=(TopRow+I+1)*P[8]; If D<=P[7] Then Begin
   S:=F(D,0)+'  '+F(POI(D,P[5]),1)+'  '+F(Mils(D)/(P[13]*Pi/10.8),0)+'  '+F(Mils(D),1)+
   '  '+F(SpeedAt(D),0);
   Txt(4,185+I*12,LightCyan,S);
  End;
 End;
 If ShowRet Then DrawReticle;
 Lo:=0; Hi:=1;
 For J:=0 To 4 Do Begin
  If J=0 Then Z:=P[5] Else Z:=Zeros[J];
  For I:=0 To 100 Do Begin
   V:=Curve(I*P[7]/100,Z);
   If V<Lo Then Lo:=V; If V>Hi Then Hi:=V;
  End
 End;
 D:=(Hi-Lo)*0.08; Lo:=Lo-D; Hi:=Hi+D;
 Box(292,184,628,435,White);
 If Zone And (GraphKind=0) Then Begin
  Y:=435-Round((P[14]/2-Lo)/(Hi-Lo)*251);
  YY:=435-Round((-P[14]/2-Lo)/(Hi-Lo)*251);
  If Y<184 Then Y:=184; If YY>435 Then YY:=435;
  If (Y<=YY) And (Y<=435) And (YY>=184) Then Box(292,Y,628,YY,LightMagenta);
 End;
 For I:=0 To 10 Do Begin
  X:=292+I*336 Div 10; Y:=435-I*251 Div 10;
  If Grid Then Begin
   SetColor(LightGray); Line(X,184,X,435); Line(292,Y,628,Y)
  End;
  If I Mod 2=0 Then Begin
   Txt(X-6,441,White,F(I*P[7]/10,0));
   Txt(257,Y,White,F(Lo+I*(Hi-Lo)/10,1));
  End
 End;
 If (Lo<=0) And (Hi>=0) Then Begin
  Y:=435-Round(-Lo/(Hi-Lo)*251); SetColor(DarkGray); Line(292,Y,628,Y)
 End;
 For J:=0 To 4 Do If (J=0) Or Enabled[J] Then Begin
  If J=0 Then Begin
   Z:=P[5]; SetColor(Red)
  End
   Else
  Begin
   Z:=Zeros[J]; SetColor(Colors[J])
  End;
  PX:=292; PY:=435-Round((Curve(0,Z)-Lo)/(Hi-Lo)*251);
  For I:=1 To 336 Do Begin
   X:=292+I; Y:=435-Round((Curve(I*P[7]/336,Z)-Lo)/(Hi-Lo)*251);
   Line(PX,PY,X,Y); PX:=X; PY:=Y;
  End;
 End;
 Txt(295,170,White,Item(3,GraphKind+1));
 Box(0,460,639,479,Blue); Txt(4,466,White,Copy(Status,1,78));
 If Menu>0 Then Begin
  X:=(Menu-1)*105; If X>414 Then X:=414;
  Box(X,20,X+224,22+ItemCount(Menu)*20,LightGray);
  For I:=1 To ItemCount(Menu) Do Begin
   If I=MenuRow Then Box(X,22+(I-1)*20,X+224,40+(I-1)*20,Blue);
   If I=MenuRow Then Idx:=White Else Idx:=Black;
   Txt(X+5,27+(I-1)*20,Idx,Item(Menu,I));
  End
 End;
 Mouse(True);
End;

Function Ask(Title,Initial:String):String;
Var
 S:String;
 C:char;
 Finished:boolean;
Begin
 S:=Initial; Finished:=False; Mouse(False);
 Repeat
 Box(65,190,575,270,LightGray); Txt(76,202,Black,Title);
 Box(76,222,564,245,White); Txt(80,230,Black,Copy(S,1,59)+'_');
 Txt(76,253,Black,'Entree: valider   Echap: annuler');
 C:=ReadKey;
 Case C Of
 #0:
 Begin
  C:=ReadKey
 End;
 #13:Finished:=True;
 #27:
 Begin
  S:=''; Finished:=True
 End;
 #8:If Length(S)>0 Then Delete(S,Length(S),1); Else
 If (C>=' ') And (Length(S)<60) Then S:=S+C;
End;
Until Finished;
Mouse(True); Ask:=S;
End;

Procedure Notice(S,T:String);
Var
 C:char;
Begin
 Mouse(False); Box(20,195,620,280,LightGray);
 Txt(30,208,Black,S); Txt(30,230,Black,T);
 Txt(30,257,Black,'Appuyez sur une touche...'); C:=ReadKey;
 If C=#0 Then C:=ReadKey; Mouse(True);
End;

Procedure EditField;
Var
 S:String;
 V,Old:real;
 E,I:integer;
Begin
 S:=Ask(Labels[Selected],F(P[Selected],3)); If S='' Then Exit;
 For I:=1 To Length(S) Do If S[I]=',' Then S[I]:='.';
 Val(S,V,E);
 If E=0 Then If Valid(Selected,V) Then Begin
  Old:=P[Selected]; P[Selected]:=V; Model;
  If K*500>12 Then Begin
   P[Selected]:=Old; Model;
   Status:='Combinaison hors modele : trainee excessive'; Exit
  End;
  TopRow:=0; Status:='Valeur modifiee'; Exit
 End;
 Status:='Valeur invalide : '+F(Minima[Selected],2)+' a '+F(Maxima[Selected],2);
End;

Procedure Profile(Save:boolean);
Var
 T:Text;
 Name,Magic:String;
 Q,Old:Array[1..NF] Of real;
 I,E:integer;
 OK:boolean;
Begin
 Name:=Ask('Fichier profil','CHAIRGUN.CHG'); If Name='' Then Exit;
 Assign(T,Name); {$I-}
 If Save Then Begin
  Rewrite(T); E:=IOResult;
  If E=0 Then Begin
   WriteLn(T,'CHAIRGUN 1');
   For I:=1 To NF Do WriteLn(T,P[I]:0:10);
   E:=IOResult; Close(T); If IOResult<>0 Then E:=1;
  End;
 End Else
 Begin
  Reset(T); E:=IOResult;
  If E=0 Then Begin
   ReadLn(T,Magic); E:=IOResult; OK:=(E=0) And (Magic='CHAIRGUN 1');
   For I:=1 To NF Do Begin
    ReadLn(T,Q[I]); E:=IOResult;
    If E<>0 Then OK:=False Else If Not Valid(I,Q[I]) Then OK:=False;
   End;
   Close(T); E:=IOResult; If Not OK Then E:=1;
   If E=0 Then Begin
    For I:=1 To NF Do Begin
     Old[I]:=P[I]; P[I]:=Q[I]
    End;
    Model;
    If K*500>12 Then Begin
     For I:=1 To NF Do P[I]:=Old[I]; Model; E:=1
    End;
    TopRow:=0
   End;
  End;
 End; {$I+}
 If E=0 Then Status:='Profil traite : '+Name Else Status:=
 'Erreur de fichier ou profil invalide';
End;

Procedure ExportCSV;
Var
 T:Text;
 Name:String;
 I,E:integer;
 X:real;
Begin
 Name:=Ask('Exporter le tableau CSV','CHAIRGUN.CSV'); If Name='' Then Exit;
 Assign(T,Name); {$I-} Rewrite(T); E:=IOResult;
 If E=0 Then Begin
  WriteLn(T,
  'distance_m;poi_cm;clics;mils;chute_cm;vitesse_ms;energie_J;temps_s;derive_cm');
  For I:=1 To Trunc(P[7]/P[8]) Do Begin
   X:=I*P[8]; WriteLn(T,F(X,3),';',F(POI(X,P[5]),4),';',
   F(Mils(X)/(P[13]*Pi/10.8),2),';',F(Mils(X),4),';',F(DropAt(X)*100,4),';',
   F(SpeedAt(X),3),';',F(P[2]/2000*Sqr(SpeedAt(X)),4),';',F(TimeAt(X),5),';',F(Drift(X),4)
   );
  End;
  E:=IOResult; Close(T); If IOResult<>0 Then E:=1;
 End; {$I+}
 If E=0 Then Status:='Tableau exporte : '+Name Else Status:='Erreur pendant export CSV';
End;

Procedure Optimal;
Var
 Z,X,First,Last,Best,BestZ:real;
 I,J:integer;
 Inside:boolean;
Begin
 Best:=0; BestZ:=P[5];
 For I:=1 To Trunc(P[7]) Do Begin
  Z:=I; First:=0; Last:=0; Inside:=False;
  For J:=1 To Trunc(P[7]*2) Do Begin
   X:=J/2;
   If Abs(POI(X,Z))<=P[14]/2 Then Begin
    If Not Inside Then Begin
     First:=X; Inside:=True
    End;
    Last:=X;
    If Last-First>Best Then Begin
     Best:=Last-First; BestZ:=Z
    End;
   End Else Inside:=False;
  End
 End;
 P[5]:=BestZ; Status:='Zero optimal '+F(BestZ,1)+' m ; plage utile '+F(Best,1)+' m';
End;

Procedure ToolBC;
Var
 S:String;
 D,V:real;
 E:integer;
Begin
 S:=Ask('Distance mesure vitesse (m)','50'); Val(S,D,E);
 If (E<>0) Or (D<=0) Or (D>500) Then Exit;
 S:=Ask('Vitesse mesuree (m/s)','140'); Val(S,V,E);
 If (E<>0) Or (V<=0) Or (V>=P[4]) Then Begin
  Status:='Vitesse attendue entre 0 et vitesse initiale'; Exit
 End;
 V:=P[3]*K/(-Ln(V/P[4])/D);
 If Valid(3,V) And (-Ln(SpeedAt(1)/P[4])*P[3]/V*500<=12) Then Begin
  P[3]:=V; Model; Status:='BC effectif ajuste au modele simplifie'
 End
 Else Status:='BC calcule hors limites du modele';
End;

Procedure RangeFinder;
Var
 S:String;
 H,A:real;
 E:integer;
Begin
 S:=Ask('Taille cible (cm)','10'); Val(S,H,E); If (E<>0) Or (H<=0) Or (H>10000) Then Exit;
 S:=Ask('Taille apparente (mils)','2'); Val(S,A,E); If (E<>0) Or (A<=0) Then Exit;
 Notice('Distance estimee : '+F(H*10/A,1)+' m',
 'Mils reels, corriges pour le grossissement.');
End;

Procedure Action(M,R:integer);Begin
 Menu:=0;
 Case M Of
 1:Case R Of 1:ResetDefaults;2:Profile(False);3:Profile(True);4:ExportCSV;5:Done:=True
End;
2:Case R Of 1:Grid:=Not Grid;2:Zone:=Not Zone;3:ShowRet:=Not ShowRet;4:EditField
End;
3:GraphKind:=R-1;
4:RetKind:=R-1;
5:Case R Of 1:Optimal;2:ToolBC;3:RangeFinder
End;
6:Case R Of
1:Notice('F1 aide; F10 menus; fleches; Entree; Tab champs.',
'1..4 courbes; PgHaut/PgBas tableau; Echap ferme.');
2:Notice('Trainee effective, densite constante, gravite 9,80665.',
'Approximation autonome : aucune equivalence G1/Hawke.');
End;
End;
End;

Procedure Click;
Var
 I,X,R:integer;
Begin
 If MY<20 Then Begin
  Menu:=MX Div 105+1; If Menu>6 Then Menu:=6; MenuRow:=1; Exit
 End;
 If Menu>0 Then Begin
  X:=(Menu-1)*105; If X>414 Then X:=414;
  R:=(MY-22) Div 20+1;
  If (MX>=X) And (MX<=X+224) And (MY>=22) And (R<=ItemCount(Menu)) Then Action(Menu,R)
                                                                   Else Menu:=0; Exit;
 End;
 If (MY>=22) And (MY<=40) Then Begin
  I:=MX Div 160+1; Enabled[I]:=Not Enabled[I]
 End;
 If (MY>=44) And (MY<164) Then Begin
  Selected:=((MY-44) Div 30)*4+MX Div 160+1; EditField
 End;
End;

Procedure Key;
Var
 C:char;
 Ext:boolean;
Begin
 C:=ReadKey; Ext:=C=#0; If Ext Then C:=ReadKey;
 If Ext Then Begin
  If C=#68 Then Begin
   Menu:=1; MenuRow:=1
  End
  Else If C=#59 Then Action(6,1) Else
  If Menu>0 Then Case C Of
  #75:
  Begin
   Dec(Menu); If Menu<1 Then Menu:=6; MenuRow:=1
  End;
  #77:
  Begin
   Inc(Menu); If Menu>6 Then Menu:=1; MenuRow:=1
  End;
  #72:
  Begin
   Dec(MenuRow); If MenuRow<1 Then MenuRow:=ItemCount(Menu)
  End;
  #80:
  Begin
   Inc(MenuRow); If MenuRow>ItemCount(Menu) Then MenuRow:=1
  End;
 End
 Else Case C Of
 #73:
 Begin
  Dec(TopRow,8); If TopRow<0 Then TopRow:=0
 End;
 #81:If (TopRow+1)*P[8]<P[7] Then Inc(TopRow);
 #75:If Selected>1 Then Dec(Selected);
 #77:If Selected<NF Then Inc(Selected);
 #72:If Selected>4 Then Dec(Selected,4);
 #80:If Selected<=NF-4 Then Inc(Selected,4);
End;
End Else Case C Of
#27:If Menu>0 Then Menu:=0 Else Done:=True;
#13:If Menu>0 Then Action(Menu,MenuRow) Else EditField;
#9:
Begin
 Inc(Selected); If Selected>NF Then Selected:=1
End;
'1'..'4':
Begin
 Enabled[Ord(C)-48]:=Not Enabled[Ord(C)-48]
End;
End;
End;

Procedure Check(B:boolean; S:String);Begin
 If Not B Then Begin
  WriteLn('ECHEC : ',S); Halt(1)
 End
End;

Procedure ShowHelp;
Begin
 {$IFDEF FPC}
 { PtcCrt redirige Output : retablir la sortie console pour l'aide. }
 Assign(Output,''); Rewrite(Output);
 {$ENDIF}
 WriteLn('CHAIRGUN - Cette commande permet de lancer le calculateur balistique graphique.');
 WriteLn;
 WriteLn('Utilisation : CHAIRGUN [/? | /TEST]');
 WriteLn('  Sans parametre : ouvrir l''interface graphique.');
 WriteLn('  /?             : afficher cette aide sans ouvrir le graphique.');
 WriteLn('  /TEST          : executer les controles numeriques.');
 WriteLn;
 WriteLn('Commandes dans l''interface :');
 WriteLn('  F10, fleches, Entree : parcourir les menus francais.');
 WriteLn('  Clic sur un champ   : modifier sa valeur.');
 WriteLn('  Tab, Entree         : selectionner puis modifier un champ.');
 WriteLn('  1 a 4               : cocher les courbes 10, 20, 30 et 50 m.');
 WriteLn('  PgHaut / PgBas      : faire defiler le tableau.');
 WriteLn('  F1                  : aide de l''interface.');
 WriteLn('  Echap               : fermer le menu, puis quitter.');
 WriteLn;
 WriteLn('Menus : graphiques, reticules, profils et export du tableau CSV.');
 WriteLn('Modele balistique simplifie, sans equivalence G1/G7 ou Hawke.');
End;

Procedure Tests;
Var
 I:integer;
Begin
 ResetDefaults;
 Check(Abs(POI(P[5],P[5]))<0.00001,'zero');
 Check(Abs(POI(0,P[5])+P[6])<0.00001,'hauteur lunette');
 Check(SpeedAt(50)<SpeedAt(10),'perte vitesse');
 Check(TimeAt(50)>TimeAt(10),'temps croissant');
 Check(Abs(Drift(50))<0.00001,'vent nul');
 P[10]:=10; Check(Drift(50)>0,'derive positive');
 P[11]:=-90; Check(Drift(50)<0,'derive negative');
 For I:=1 To NF Do Begin
  Check(Valid(I,Defaults[I]),'valeur initiale');
  Check(Not Valid(I,Minima[I]-1),'borne minimale');
  Check(Not Valid(I,Maxima[I]+1),'borne maximale');
 End;
 Optimal; Check(Valid(5,P[5]),'zero optimal');
 WriteLn('OK : zero, hauteur, vitesse, temps, vent, 48 bornes, optimisation.');
End;

Var
 Driver,Mode,Err:integer;

BEGIN
 If ParamCount>0 Then If ParamStr(1)='/?' Then Begin
  ShowHelp; Halt(0)
 End;
 If ParamCount>0 Then If (ParamStr(1)='/TEST') Or (ParamStr(1)='/test') Then Begin
  Tests; Halt
 End;
 ResetDefaults; Done:=False; Menu:=0; OldB:=0;
 Status:='F10 menus | Entree modifier | Tab champ | 1..4 courbes | F1 aide';
 {$IFDEF FPC}
  Driver:=VGA; Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect; Mode:=0;
 {$ENDIF}
 InitGraph(Driver,Mode,''); Err:=GraphResult;
 If Err<>grOk Then Begin
  WriteLn(GraphErrorMsg(Err)); Halt(1)
 End;
 {$IFDEF FPC}
  PtcMouse.InitMouse;
 {$ENDIF}
 Mouse(True); Draw;
 Repeat
 Poll;
 If (MB And 1<>0) And (OldB And 1=0) Then Begin
  Click; Draw
 End;
 OldB:=MB;
 If KeyPressed Then Begin
  Key; Draw
 End;
 Delay(10);
 Until Done;
 Mouse(False); CloseGraph;
END.
