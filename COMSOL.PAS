{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/ballistics-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2) 
  @description: Solveur autonome 2D differences finies, pas le moteur COMSOL. 
  Format natif texte CSM; MPH/classes delegues a COMSOL_BATCH. }

Program COMSOL;

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
 MaxN=40;
 NP=10;
 Names:Array[1..NP] Of String[12]=('largeur','hauteur','conductivite','source',
 'gauche','droite','bas','haut','tolerance','iterations');
 Captions:Array[1..NP] Of String[24]=('Largeur (m)','Hauteur (m)',
 'Conductivite (W/mK,S/m)','Source (W/m3,A/m3)','Bord gauche (K,V)',
 'Bord droit (K,V)','Bord bas (K,V)','Bord haut (K,V)',
 'Tolerance absolue','Iterations maximales');
 Defaults:Array[1..NP] Of real=(0.1,0.1,10,0,350,300,300,300,0.0001,5000);
 Nodes:Array[1..11] Of String[26]=('Modele 1','  Definitions','    Parametres',
 '  Composant 1 (2D)','    Geometrie : rectangle','    Materiau homogene',
 '    Physique','    Conditions aux limites','    Maillage structure',
 '  Etude stationnaire std1','  Resultats');
 MenuNames:Array[1..7] Of String[10]=('Fichier','Modele','Physique','Maillage','Etude',
 'Resultats','Aide');

Var
 P:Array[1..NP] Of real;
 U:Array[0..MaxN,0..MaxN] Of real;
 N,Physics,Selected,Field,Menu,MenuRow,View,Iter:integer;
 MeshReady,Solved,Converged,Cancelled,Quit,GraphOpen,ShowMesh:boolean;
 InputFile,OutputFile,LogFile,Study,Job,Method,ParamFile,PNam,PList,PIndex,
 LicenseFile:String;
 NoSave,Graphics,LogOut,ClearMeshOpt,ClearSolOpt,CancelOpt,Testing,BatchMode:boolean;
 Alive:real;
 Status,ModelFile:String;
 Residual:real;
 MX,MY,MB,OldB:integer;

Function Upper(S:String):String;
Var
 I:integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]); Upper:=S
End;

Function F(V:real; D:integer):String;
Var
 S:String;
Begin
 Str(V:0:D,S); F:=S
End;

Procedure Console;Begin
 {$IFDEF FPC}
  Assign(Output,''); Rewrite(Output);
 {$ENDIF}
End;

Procedure Fail(S:String);Begin
 If GraphOpen Then CloseGraph;
 Console; WriteLn('Erreur : ',S); Halt(1);
End;

Procedure Log(S:String);
Var
 T:Text;
 E:integer;
Begin
 Status:=S;
 If LogOut And Not GraphOpen Then WriteLn(S);
 If LogFile='' Then Exit;
 Assign(T,LogFile); {$I-}Append(T); E:=IOResult;
 If E<>0 Then Begin
  Rewrite(T); E:=IOResult
 End;
 If E=0 Then Begin
  WriteLn(T,S); E:=IOResult; Close(T); If IOResult<>0 Then E:=1
 End;
 {$I+} If E<>0 Then Fail('Impossible d''ecrire le journal '+LogFile);
End;

Function Extension(S:String):String;
Var
 D:DirStr;
 A:NameStr;
 E:ExtStr;
Begin
 FSplit(S,D,A,E); Extension:=Upper(E)
End;

Function Valid(I:integer; V:real):boolean;Begin
 Valid:=False;
 Case I Of
 1,2:Valid:=(V>=0.000001) And (V<=10000);
 3:Valid:=(V>=0.000001) And (V<=1000000);
 4..8:Valid:=(V>=-1.0E9) And (V<=1.0E9);
 9:Valid:=(V>=1.0E-10) And (V<=1);
 10:Valid:=(V>=1) And (V<=30000) And (V=Trunc(V));
End;
End;

Procedure Invalidate;Begin
 Solved:=False; Converged:=False; Iter:=0
End;

Procedure NewModel;
Var
 I:integer;
Begin
 For I:=1 To NP Do P[I]:=Defaults[I];
 N:=20; Physics:=0; MeshReady:=False; Invalidate; Cancelled:=False;
 ModelFile:='Sans titre.csm'; Selected:=1; Field:=1; View:=0; ShowMesh:=True;
 Status:='Nouveau modele : conduction thermique stationnaire';
End;

Procedure Help;Begin
 Console;
 WriteLn('COMSOL - Cette commande permet de lancer l''interface graphique et solveur autonome 2D.');
 WriteLn;
 WriteLn('Syntaxe : COMSOL [batch] [options]');
 WriteLn;
 WriteLn('Sans options : ouvrir l''interface graphique francaise.');
 WriteLn('  /? ou -help           Afficher cette aide');
 WriteLn('  -inputfile fichier    Modele .csm ; MPH/classe via COMSOL_BATCH');
 WriteLn('  -outputfile fichier   Sortie .csm (ou sortie du moteur externe)');
 WriteLn('  -study tag            Etude std1');
 WriteLn('  -job tag              Tache sol1');
 WriteLn('  -methodcall tag       reset, mesh ou solve (format autonome)');
 WriteLn('  -batchlog fichier     Journal d''execution');
 WriteLn('  -batchlogout          Messages aussi sur la sortie standard');
 WriteLn('  -alivetime secondes   Intervalle des messages d''etat');
 WriteLn('  -checklicense fichier Exigences : CSM libre, MPH moteur externe');
 WriteLn('  -clearmesh            Effacer le maillage avant execution');
 WriteLn('  -clearsolution        Effacer la solution avant execution');
 WriteLn('  -graphics             Afficher le resultat du calcul');
 WriteLn('  -nosave               Ne pas enregistrer le modele final');
 WriteLn('  -paramfile fichier    Parametres texte nom=valeur');
 WriteLn('  -pname noms           Noms separes par des virgules');
 WriteLn('  -plist valeurs        Une valeur par nom, separee par virgules');
 WriteLn('  -pindex indices       Indices de lignes du fichier de parametres');
 WriteLn('  -cancel               Annuler cette execution avant calcul');
 WriteLn('  /TEST                 Verifications numeriques sans fenetre');
 WriteLn;
 WriteLn('Parametres : largeur, hauteur, conductivite, source, gauche,');
 WriteLn('droite, bas, haut, tolerance, iterations, n (4..40), physique (0..1).');
 WriteLn('Physique 0 : thermique ; 1 : potentiel electrique stationnaire.');
 WriteLn('CSM : rectangle homogene, quatre bords de Dirichlet constants.');
 WriteLn('Pas de balayage : -pindex selectionne les lignes nom=valeur.');
 WriteLn('Pour les vrais MPH/classes, definir COMSOL_BATCH vers le moteur');
 WriteLn('comsolbatch.exe installe ; toutes les options lui sont transmises.');
 WriteLn('F10 menus, fleches, Entree ; F5 calcul ; Echap ferme/quitte.');
End;

Function ArgValue(Var I:integer):String;Begin
 Inc(I); If I>ParamCount Then Fail('Valeur manquante pour '+ParamStr(I-1));
 ArgValue:=ParamStr(I)
End;

Function Number(S:String):real;
Var
 V:real;
 E:integer;
Begin
 Val(S,V,E); If E<>0 Then Fail('Nombre invalide : '+S);
 If (V<>V) Or (Abs(V)>1.0E12) Then Fail('Nombre hors limites'); Number:=V;
End;

Procedure Parse;
Var
 I:integer;
 A,S:String;
Begin
 I:=1;
 While I<=ParamCount Do Begin
  A:=Upper(ParamStr(I));
  If (A='/?') Or (A='-HELP') Or (A='--HELP') Then Begin
   Help; Halt(0)
  End
  Else If (A='/TEST') Then Testing:=True Else
  If A='BATCH' Then BatchMode:=True Else
  If A='-INPUTFILE' Then InputFile:=ArgValue(I) Else
  If A='-OUTPUTFILE' Then OutputFile:=ArgValue(I) Else
  If A='-STUDY' Then Study:=ArgValue(I) Else
  If A='-JOB' Then Job:=ArgValue(I) Else
  If A='-METHODCALL' Then Method:=ArgValue(I) Else
  If A='-BATCHLOG' Then LogFile:=ArgValue(I) Else
  If A='-BATCHLOGOUT' Then LogOut:=True Else
  If A='-ALIVETIME' Then Begin
   S:=ArgValue(I); Alive:=Number(S); If Alive<=0 Then Fail('Intervalle positif requis')
  End
  Else If A='-CHECKLICENSE' Then LicenseFile:=ArgValue(I) Else
  If A='-CLEARMESH' Then ClearMeshOpt:=True Else
  If (A='-CLEARSOLUTION') Or (A='-CLEARSOL') Then ClearSolOpt:=True Else
  If A='-GRAPHICS' Then Graphics:=True Else
  If A='-NOSAVE' Then NoSave:=True Else
  If A='-PARAMFILE' Then ParamFile:=ArgValue(I) Else
  If A='-PNAME' Then PNam:=ArgValue(I) Else
  If A='-PLIST' Then PList:=ArgValue(I) Else
  If A='-PINDEX' Then PIndex:=ArgValue(I) Else
  If A='-CANCEL' Then CancelOpt:=True
                 Else Fail('Option inconnue : '+ParamStr(I));
  Inc(I);
 End;
End;

Function Trim(S:String):String;Begin
 While (Length(S)>0) And (S[1]<=' ') Do Delete(S,1,1);
 While (Length(S)>0) And (S[Length(S)]<=' ') Do Delete(S,Length(S),1);
 Trim:=S;
End;

Function Token(Var S:String):String;
Var
 I:integer;
Begin
 I:=Pos(',',S); If I=0 Then Begin
  Token:=Trim(S); S:=''
 End
  Else
 Begin
  Token:=Trim(Copy(S,1,I-1)); Delete(S,1,I)
 End;
End;

Procedure SetParam(Name,Value:String);
Var
 I:integer;
 V:real;
Begin
 Name:=Upper(Trim(Name)); V:=Number(Trim(Value));
 If Name='N' Then Begin
  If (V<4) Or (V>MaxN) Or (V<>Trunc(V)) Then Fail('n doit etre entier entre 4 et 40');
  N:=Round(V); MeshReady:=False; Invalidate; Exit
 End;
 If Name='PHYSIQUE' Then Begin
  If (V<>0) And (V<>1) Then Fail('physique doit valoir 0 ou 1');
  Physics:=Round(V); Invalidate; Exit
 End;
 For I:=1 To NP Do If Upper(Names[I])=Name Then Begin
  If Not Valid(I,V) Then Fail('Parametre hors limites : '+Name);
  P[I]:=V; Invalidate; Exit
 End;
 Fail('Parametre inconnu : '+Name);
End;

Function Chosen(Index:integer):boolean;
Var
 S,T:String;
 V:real;
Begin
 Chosen:=PIndex=''; S:=PIndex;
 While S<>'' Do Begin
  T:=Token(S); V:=Number(T);
  If (V<1) Or (V<>Trunc(V)) Then Fail('Indice de parametre invalide');
  If V=Index Then Chosen:=True;
 End;
End;

Procedure ReadParams;
Var
 T:Text;
 S:String;
 I,Idx,E:integer;
Begin
 If ParamFile='' Then Begin
  If PIndex<>'' Then Fail('-pindex exige -paramfile'); Exit
 End;
 Assign(T,ParamFile); {$I-}Reset(T); E:=IOResult;{$I+}
 If E<>0 Then Fail('Impossible de lire '+ParamFile);
 Idx:=0;
 While Not Eof(T) Do Begin
  ReadLn(T,S); S:=Trim(S);
  If (S<>'') And (S[1]<>'#') Then Begin
   Inc(Idx); I:=Pos('=',S); If I=0 Then Fail('Ligne attendue : nom=valeur');
   If Chosen(Idx) Then SetParam(Copy(S,1,I-1),Copy(S,I+1,255));
  End;
 End;
 Close(T);
 S:=PIndex;
 While S<>'' Do If Number(Token(S))>Idx Then Fail('Indice absent du fichier');
End;

Procedure ApplyLists;
Var
 A,B,Name,Value:String;
Begin
 A:=PNam; B:=PList;
 While (A<>'') Or (B<>'') Do Begin
  Name:=Token(A); Value:=Token(B);
  If (Name='') Or (Value='') Then Fail('-pname et -plist : nombres de valeurs differents')
  ;
  SetParam(Name,Value);
 End;
End;

Procedure SaveModel(Name:String);
Var
 T:Text;
 I,J,E:integer;
Begin
 If Extension(Name)<>'.CSM' Then Begin
  Log('Enregistrer avec extension .csm uniquement'); Exit
 End;
 Assign(T,Name); {$I-}Rewrite(T); E:=IOResult;
 If E=0 Then Begin
  WriteLn(T,'PASCAL-COMSOL 1'); WriteLn(T,N,' ',Physics);
  For I:=1 To NP Do WriteLn(T,P[I]:0:12);
  WriteLn(T,Ord(MeshReady),' ',Ord(Solved),' ',Ord(Converged),' ',Iter,' ',Residual:0:12);
  If Solved Then
  For J:=0 To N Do
  For I:=0 To N Do WriteLn(T,U[I,J]:0:12);
  E:=IOResult; Close(T); If IOResult<>0 Then E:=1;
 End;{$I+}
 If E<>0 Then Fail('Echec enregistrement '+Name);
 ModelFile:=Name; Log('Modele enregistre : '+Name);
End;

Procedure LoadModel(Name:String);
Var
 T:Text;
 Magic:String;
 I,J,E,A,B,C,NN,Ph,It:integer;
 Q:Array[1..NP] Of real;
 R:real;
 Good:boolean;
Begin
 If Extension(Name)<>'.CSM' Then Begin
  Log('MPH/classe : utiliser -inputfile avec COMSOL_BATCH configure'); Exit
 End;
 Assign(T,Name); {$I-}Reset(T); E:=IOResult;{$I+}
 If E<>0 Then Fail('Impossible de lire '+Name);
 {$I-}
 ReadLn(T,Magic); E:=IOResult; Good:=(E=0) And (Magic='PASCAL-COMSOL 1');
 ReadLn(T,NN,Ph); E:=IOResult;
 Good:=Good And (E=0) And (NN>=4) And (NN<=MaxN) And (Ph>=0) And (Ph<=1);
 For I:=1 To NP Do Begin
  ReadLn(T,Q[I]); E:=IOResult;
  If E<>0 Then Good:=False Else If Not Valid(I,Q[I]) Then Good:=False
 End;
 ReadLn(T,A,B,C,It,R); E:=IOResult;
 Good:=Good And (E=0) And (A>=0) And (A<=1) And (B>=0) And (B<=1) And (C>=0) And (C<=1)
 And (It>=0) And (It<=30000);
 If Not Good Then Begin
  Close(T); E:=IOResult; {$I+}Fail('Format CSM invalide')
 End;
 {$I-}
 If B=1 Then
 For J:=0 To NN Do
 For I:=0 To NN Do Begin
  ReadLn(T,U[I,J]); E:=IOResult;
  If E<>0 Then Good:=False Else If (U[I,J]<>U[I,J]) Or (Abs(U[I,J])>1.0E30) Then Good:=
  False;
 End;
 Close(T); E:=IOResult;{$I+}
 If Not Good Then Fail('Solution CSM incomplete ou invalide');
 N:=NN; Physics:=Ph;
 For I:=1 To NP Do P[I]:=Q[I];
 MeshReady:=A=1; Solved:=B=1; Converged:=C=1; Iter:=It; Residual:=R;
 ModelFile:=Name; Log('Modele charge : '+Name);
End;

Function Seconds:real;
Var
 H,M,S,HS:word;
Begin
 GetTime(H,M,S,HS); Seconds:=H*3600.0+M*60.0+S+HS/100.0
End;

Procedure Solve(Interactive:boolean);
Var
 I,J:integer;
 AX,AY,V,D,Last,NowT:real;
 C:char;
Begin
 MeshReady:=True; Invalidate; Cancelled:=False;
 For J:=0 To N Do
 For I:=0 To N Do U[I,J]:=(P[5]+P[6]+P[7]+P[8])/4;
 For I:=0 To N Do Begin
  U[I,0]:=P[7]; U[I,N]:=P[8]
 End;
 For J:=0 To N Do Begin
  U[0,J]:=P[5]; U[N,J]:=P[6]
 End;
 AX:=Sqr(N/P[1]); AY:=Sqr(N/P[2]); Last:=Seconds;
 Log('Calcul stationnaire : std1 / sol1');
 Repeat
 Inc(Iter); Residual:=0;
 For J:=1 To N-1 Do
 For I:=1 To N-1 Do Begin
  V:=(AX*(U[I-1,J]+U[I+1,J])+AY*(U[I,J-1]+U[I,J+1])+P[4]/P[3])/(2*(AX+AY));
  D:=Abs(V-U[I,J]); If D>Residual Then Residual:=D; U[I,J]:=V;
 End;
 If Interactive And KeyPressed Then Begin
  C:=ReadKey;
  If C=#0 Then C:=ReadKey Else If C=#27 Then Cancelled:=True
 End;
 NowT:=Seconds; If NowT<Last Then Last:=Last-86400;
 If NowT-Last>=Alive Then Begin
  Log('Iteration '+F(Iter,0)+' ; variation '+F(Residual,8)); Last:=NowT
 End;
 Until (Residual<P[9]) Or (Iter>=Round(P[10])) Or Cancelled;
 Converged:=(Residual<P[9]) And Not Cancelled; Solved:=Not Cancelled;
 If Cancelled Then Log('Calcul annule par Echap') Else
 If Converged Then Log('Convergence en '+F(Iter,0)+' iterations')
              Else Log('Limite atteinte : solution non convergee');
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

Procedure Box(X,Y,R,B,C:integer);Begin
 SetFillStyle(SolidFill,C); Bar(X,Y,R,B)
End;

Procedure Txt(X,Y,C:integer; S:String);Begin
 SetColor(C); OutTextXY(X,Y,S)
End;

Function Count(M:integer):integer;Begin
 Case M Of 1:Count:=6;2:Count:=2;3:Count:=2;4:Count:=3;5:Count:=3;6:Count:=4;Else Count:=2
End
End;

Function Item(M,R:integer):String;Begin
 Item:='';
 Case M Of
 1:Case R Of 1:Item:='Nouveau modele';2:Item:='Ouvrir CSM';3:Item:='Enregistrer CSM';
 4:Item:='Executer MPH externe';5:Item:='Exporter tableau CSV';6:Item:='Quitter'
End;
2:Case R Of 1:Item:='Modifier le parametre';2:Item:='Parametre suivant'
End;
3:Case R Of 1:Item:='Conduction thermique';2:Item:='Potentiel electrique'
End;
4:Case R Of 1:Item:='Construire le maillage';2:Item:='Nombre de subdivisions';
3:Item:='Effacer le maillage'
End;
5:Case R Of 1:Item:='Calculer std1 (F5)';2:Item:='Effacer la solution';
3:Item:='Initialiser les valeurs'
End;
6:Case R Of 1:Item:='Champ scalaire';2:Item:='Maillage';3:Item:='Flux / courant';
4:Item:='Geometrie'
End;
7:Case R Of 1:Item:='Commandes';2:Item:='Modele et limites'
End;
End;
End;

Procedure Limits(Var Lo,Hi:real);
Var
 I,J:integer;
Begin
 Lo:=U[0,0]; Hi:=Lo;
 For J:=0 To N Do
 For I:=0 To N Do Begin
  If U[I,J]<Lo Then Lo:=U[I,J]; If U[I,J]>Hi Then Hi:=U[I,J]
 End;
End;

Procedure Draw;
Const
 Palette:Array[0..7] Of integer=(Blue,LightBlue,Cyan,LightCyan,Green,Yellow,LightRed,Red);
Var
 I,J,X,Y,C,R,B,Idx:integer;
 Lo,Hi,V,DX,DY,L:real;
 S:String;
Begin
 Mouse(False); Box(0,0,639,479,LightGray);
 Box(0,0,639,19,Blue);
 For I:=1 To 7 Do Txt((I-1)*90+3,6,White,MenuNames[I]);
 Box(0,21,639,43,White);
 Txt(5,28,Blue,'[Nouveau]  [Ouvrir]  [Enregistrer]  [Mailler]  [Calculer F5]');
 Box(2,46,181,420,White); Box(185,46,383,420,White); Box(387,46,637,355,White);
 Txt(7,54,Blue,'Arbre du modele'); Txt(190,54,Blue,'Reglages');
 Txt(393,54,Blue,'Graphiques');
 For I:=1 To 11 Do Begin
  If Selected=I Then Begin
   Box(4,70+(I-1)*18,179,86+(I-1)*18,Blue); C:=White
  End Else C:=Black;
  S:=Nodes[I];
  If I=7 Then If Physics=0 Then S:='    Transfert thermique' Else S:=
  '    Courants electriques';
  Txt(6,75+(I-1)*18,C,Copy(S,1,21));
 End;
 Txt(7,285,Black,'Rectangle 2D'); Txt(7,303,Black,F(P[1],3)+' x '+F(P[2],3)+' m');
 Txt(7,325,Black,'Noeuds : '+F(Sqr(N+1),0));
 If MeshReady Then S:='Construit' Else S:='Non construit'; Txt(7,343,Black,S);
 For I:=1 To NP Do Begin
  Y:=73+(I-1)*31; Txt(190,Y,Black,Copy(Captions[I],1,23));
  If Field=I Then C:=Blue Else C:=DarkGray;
  Box(190,Y+10,378,Y+25,C); Txt(195,Y+14,White,F(P[I],6));
 End;
 Txt(190,390,Black,'Cliquer pour modifier');
 Txt(393,75,Black,'x (m) / y (m)');
 Lo:=0; Hi:=1; If Solved Then Limits(Lo,Hi);
 For J:=0 To N-1 Do
 For I:=0 To N-1 Do Begin
  X:=403+I*205 Div N; R:=403+(I+1)*205 Div N;
  Y:=325-(J+1)*205 Div N; B:=325-J*205 Div N;
  C:=LightGray;
  If Solved And (View<>1) And (View<>3) Then Begin
   V:=(U[I,J]+U[I+1,J]+U[I,J+1]+U[I+1,J+1])/4;
   If Hi-Lo>1.0E-20 Then Idx:=Round((V-Lo)/(Hi-Lo)*7) Else Idx:=3;
   If Idx<0 Then Idx:=0; If Idx>7 Then Idx:=7; C:=Palette[Idx];
  End;
  Box(X,Y,R,B,C);
 End;
 SetColor(Black); Rectangle(403,120,608,325);
 If (View=1) Or (ShowMesh And (View<>3) And MeshReady) Then Begin
  SetColor(DarkGray);
  For I:=0 To N Do Begin
   X:=403+I*205 Div N; Line(X,120,X,325); Y:=325-I*205 Div N; Line(403,Y,608,Y)
  End;
 End;
 If Solved And (View=2) Then Begin
  SetColor(Black);
  For J:=2 To N-2 Do If J Mod 3=0 Then
  For I:=2 To N-2 Do If I Mod 3=0 Then Begin
   DX:=-(U[I+1,J]-U[I-1,J])*N/P[1]/2;
   DY:=-(U[I,J+1]-U[I,J-1])*N/P[2]/2; L:=Sqrt(DX*DX+DY*DY);
   If L>1.0E-20 Then Begin
    X:=403+I*205 Div N; Y:=325-J*205 Div N;
    R:=X+Round(DX/L*9); B:=Y-Round(DY/L*9); Line(X,Y,R,B); Circle(R,B,1);
   End
  End;
 End;
 If Solved Then Begin
  Txt(393,88,Blue,'Min '+F(Lo,3)); Txt(393,102,Red,'Max '+F(Hi,3));
  For I:=0 To 7 Do Box(615,120+(7-I)*25,628,144+(7-I)*25,Palette[I]);
 End;
 Txt(403,334,Black,'0        '+F(P[1],3)+' m');
 Box(387,360,637,453,White); Txt(392,367,Blue,'Messages / Progression');
 Txt(392,386,Black,'Iterations : '+F(Iter,0));
 Txt(392,401,Black,'Variation : '+F(Residual,7));
 If Solved Then If Converged Then S:='Solution convergee' Else S:='NON CONVERGE' Else S:=
 'Aucune solution';
 Txt(392,418,Black,S); Txt(392,437,Blue,'Echap pendant calcul : annuler');
 Txt(6,434,Black,Copy(ModelFile,1,46));
 Box(0,459,639,479,Blue); Txt(4,466,White,Copy(Status,1,78));
 If Menu>0 Then Begin
  X:=(Menu-1)*90; If X>404 Then X:=404;
  Box(X,20,X+234,22+Count(Menu)*20,LightGray);
  For I:=1 To Count(Menu) Do Begin
   If MenuRow=I Then Begin
    Box(X,22+(I-1)*20,X+234,41+(I-1)*20,Blue); C:=White
   End Else C:=Black;
   Txt(X+4,27+(I-1)*20,C,Item(Menu,I));
  End
 End;
 Mouse(True);
End;

Function Ask(Title,Initial:String):String;
Var
 S:String;
 C:char;
 Stop:boolean;
Begin
 Mouse(False); S:=Initial; Stop:=False;
 Repeat
 Box(35,190,605,275,LightGray); Txt(45,202,Black,Title);
 Box(45,222,595,245,White); Txt(49,230,Black,Copy(S,1,65)+'_');
 Txt(45,257,Black,'Entree valider ; Echap annuler ; Retour effacer'); C:=ReadKey;
 Case C Of
 #0:C:=ReadKey;
 #27:
 Begin
  S:=''; Stop:=True
 End;
 #13:Stop:=True;
 #8:If Length(S)>0 Then Delete(S,Length(S),1); Else
 If (C>=' ') And (Length(S)<200) Then S:=S+C;
End;
Until Stop; Mouse(True); Ask:=S;
End;

Procedure Notice(A,B:String);
Var
 C:char;
Begin
 Mouse(False); Box(15,185,625,280,LightGray);
 Txt(25,202,Black,A); Txt(25,224,Black,B); Txt(25,255,Black,'Appuyez sur une touche...');
 C:=ReadKey; If C=#0 Then C:=ReadKey; Mouse(True);
End;

Procedure Edit;
Var
 S:String;
 V:real;
 E:integer;
Begin
 S:=Ask(Captions[Field],F(P[Field],6)); If S='' Then Exit;
 Val(S,V,E);
 If E=0 Then If Valid(Field,V) Then Begin
  P[Field]:=V; Invalidate; Status:='Parametre modifie'; Exit
 End;
 Status:='Valeur invalide ou hors limites';
End;

Procedure ExportCSV(Name:String);
Var
 T:Text;
 I,J,E:integer;
 QX,QY:real;
Begin
 If Not Solved Then Begin
  Log('Calculer avant export'); Exit
 End;
 Assign(T,Name); {$I-}Rewrite(T); E:=IOResult;
 If E=0 Then Begin
  WriteLn(T,'x_m;y_m;champ;flux_x;flux_y');
  For J:=1 To N-1 Do
  For I:=1 To N-1 Do Begin
   QX:=-P[3]*(U[I+1,J]-U[I-1,J])*N/(2*P[1]);
   QY:=-P[3]*(U[I,J+1]-U[I,J-1])*N/(2*P[2]);
   WriteLn(T,F(I*P[1]/N,8),';',F(J*P[2]/N,8),';',F(U[I,J],8),';',F(QX,8),';',F(QY,8));
  End;
  E:=IOResult; Close(T); If IOResult<>0 Then E:=1;
 End;{$I+}
 If E<>0 Then Fail('Export CSV impossible'); Log('Tableau exporte : '+Name);
End;

Function Quoted(S:String):String;Begin
 If Pos('"',S)>0 Then Fail('Guillemet interdit dans un argument externe');
 Quoted:='"'+S+'"';
End;

Procedure ExternalRun(FileName:String; FromCLI:boolean);
Var
 Engine,Args,A:String;
 I,Code:integer;
Begin
 Engine:=GetEnv('COMSOL_BATCH');
 If Engine='' Then Begin
  If FromCLI Then Fail('MPH/classe : definir COMSOL_BATCH vers comsolbatch.exe')
   Else
  Begin
   Notice('MPH exige le moteur COMSOL installe.',
   'Definir COMSOL_BATCH vers comsolbatch.exe.'); Exit
  End;
 End;
 Args:='';
 If FromCLI Then Begin
  For I:=1 To ParamCount Do Begin
   A:=ParamStr(I);
   If Upper(A)<>'BATCH' Then Begin
    If Length(Args)+Length(A)+3>240 Then Fail('Arguments externes trop longs pour TP7');
    Args:=Args+Quoted(A)+' ';
   End;
  End;
 End Else Args:='-inputfile '+Quoted(FileName);
 If GraphOpen Then Begin
  Mouse(False); CloseGraph; GraphOpen:=False
 End;
 SwapVectors; Exec(Engine,Args); SwapVectors; Code:=DosError;
 If Code<>0 Then Fail('Impossible de lancer COMSOL_BATCH : '+F(Code,0));
 Code:=DosExitCode; Console; WriteLn('Moteur COMSOL termine, code : ',Code);
 Halt(Code);
End;

Procedure Action(M,R:integer);
Var
 S:String;
 V:real;
 E:integer;
Begin
 Menu:=0;
 Case M Of
 1:Case R Of
 1:NewModel;
 2:
 Begin
  S:=Ask('Ouvrir modele texte .csm','MODELE.CSM'); If S<>'' Then LoadModel(S)
 End;
 3:
 Begin
  S:=Ask('Enregistrer modele .csm',ModelFile); If S<>'' Then SaveModel(S)
 End;
 4:
 Begin
  S:=Ask('Executer avec moteur COMSOL externe','MODELE.MPH');
  If S<>'' Then ExternalRun(S,False)
 End;
 5:
 Begin
  S:=Ask('Exporter resultats CSV','RESULTAT.CSV'); If S<>'' Then ExportCSV(S)
 End;
 6:Quit:=True;
End;
2:If R=1 Then Edit Else
Begin
 Inc(Field); If Field>NP Then Field:=1
End;
3:
Begin
 Physics:=R-1; Invalidate
End;
4:Case R Of
1:
Begin
 MeshReady:=True; Status:='Maillage structure construit'
End;
2:
Begin
 S:=Ask('Subdivisions par axe (4..40)',F(N,0)); Val(S,V,E);
 If E=0 Then If (V>=4) And (V<=MaxN) And (V=Trunc(V)) Then Begin
  N:=Round(V); MeshReady:=False; Invalidate
 End;
End;
3:
Begin
 MeshReady:=False; Invalidate
End;
End;
5:Case R Of
1:
Begin
 Status:='Calcul en cours... Echap annule'; Draw; Mouse(False); Solve(True); Mouse(True)
End;
2:Invalidate;
3:NewModel;
End;
6:View:=R-1;
7:If R=1 Then Notice('F10 menus, fleches, Entree ; F5 calcul ; Tab champ.',
'Arbre et champs cliquables ; Echap quitte ou annule.')
Else Notice('Solveur 2D : -div(k grad u) = source, bords fixes.',
'MPH natif : moteur externe ; fichiers autonomes .csm.');
End;
End;

Procedure Click;
Var
 X,R:integer;
Begin
 If MY<20 Then Begin
  Menu:=MX Div 90+1; If Menu>7 Then Menu:=7; MenuRow:=1; Exit
 End;
 If Menu>0 Then Begin
  X:=(Menu-1)*90; If X>404 Then X:=404; R:=(MY-22) Div 20+1;
  If (MY>=22) And (MX>=X) And (MX<=X+234) And (R>=1) And (R<=Count(Menu)) Then Action(
  Menu,R) Else Menu:=0;
  Exit
 End;
 If (MY>=21) And (MY<=43) Then Begin
  If MX<85 Then Action(1,1) Else If MX<165 Then Action(1,2) Else
  If MX<290 Then Action(1,3) Else If MX<380 Then Action(4,1) Else Action(5,1); Exit
 End;
 If (MX<182) And (MY>=70) And (MY<268) Then Begin
  Selected:=(MY-70) Div 18+1;
  Case Selected Of 3:Field:=1;5:
  Begin
   Field:=1; View:=3
  End;
  6:Field:=3;7:Field:=4;8:Field:=5;9:View:=1;10:Field:=9;11:View:=0
 End;
End;
If (MX>=185) And (MX<=383) And (MY>=73) And (MY<383) Then Begin
 Field:=(MY-73) Div 31+1; Edit
End;
End;

Procedure Key;
Var
 C:char;
Begin
 C:=ReadKey;
 If C=#0 Then Begin
  C:=ReadKey;
  If C=#63 Then Action(5,1) Else
  If C=#59 Then Action(7,1) Else
  If C=#68 Then Begin
   Menu:=1; MenuRow:=1
  End
  Else If Menu>0 Then Case C Of
  #75:
  Begin
   Dec(Menu); If Menu<1 Then Menu:=7; MenuRow:=1
  End;
  #77:
  Begin
   Inc(Menu); If Menu>7 Then Menu:=1; MenuRow:=1
  End;
  #72:
  Begin
   Dec(MenuRow); If MenuRow<1 Then MenuRow:=Count(Menu)
  End;
  #80:
  Begin
   Inc(MenuRow); If MenuRow>Count(Menu) Then MenuRow:=1
  End;
 End
 Else Case C Of
 #72:If Selected>1 Then Dec(Selected);
 #80:If Selected<11 Then Inc(Selected);
End;
End Else Case C Of
#27:If Menu>0 Then Menu:=0 Else Quit:=True;
#13:If Menu>0 Then Action(Menu,MenuRow) Else Edit;
#9:
Begin
 Inc(Field); If Field>NP Then Field:=1
End;
End;
End;

Procedure OpenGraphics;
Var
 D,M,E:integer;
Begin
 {$IFDEF FPC}
  D:=VGA; M:=VGAHi;
 {$ELSE}
  D:=Detect; M:=0;
 {$ENDIF}
 InitGraph(D,M,''); E:=GraphResult;
 If E<>grOk Then Fail(GraphErrorMsg(E)); GraphOpen:=True;
 {$IFDEF FPC}
  PtcMouse.InitMouse;
 {$ENDIF}
 Mouse(True);
End;

Procedure Check(B:boolean; S:String);Begin
 If Not B Then Fail('TEST : '+S)
End;

Procedure Tests;
Var
 I,J:integer;
 Error:real;
Begin
 NewModel;
 For I:=5 To 8 Do P[I]:=300;
 Solve(False); Check(Converged,'champ constant convergence');
 For J:=0 To N Do
 For I:=0 To N Do Check(Abs(U[I,J]-300)<1.0E-8,'champ constant');
 NewModel; N:=16; P[1]:=1; P[2]:=1; P[3]:=1; P[4]:=1;
 For I:=5 To 8 Do P[I]:=0;
 P[9]:=1.0E-8; Solve(False);
 Check(Converged,'Poisson convergence'); Check(U[8,8]>0,'source positive');
 Error:=0;
 For J:=1 To N-1 Do
 For I:=1 To N-1 Do If Abs((4*U[I,J]-U[I-1,J]-U[I+1,J]-U[I,J-1]-U[I,J+1])*Sqr(N)-1)>
 Error Then Error:=Abs((4*U[I,J]-U[I-1,J]-U[I+1,J]-U[I,J-1]-U[I,J+1])*Sqr(N)-1);
 Check(Error<0.0001,'residu equation');
 Check(Abs(U[4,8]-U[12,8])<0.00001,'symetrie');
 P[10]:=1; Solve(False); Check(Not Converged,'non convergence signalee');
 WriteLn('OK : champ constant, Poisson, residu, symetrie, limite iterations.');
End;

Var
 HasBatch:boolean;

BEGIN
 Console; NewModel; Alive:=10; OldB:=0; Quit:=False; Menu:=0;
 GraphOpen:=False; Parse;
 If Testing Then Begin
  Tests; Halt(0)
 End;
 If InputFile<>'' Then If Extension(InputFile)<>'.CSM' Then ExternalRun(InputFile,True);
 If CancelOpt Then Begin
  LogOut:=True; Log('Execution annulee avant calcul (aucun processus distant arrete)');
  Halt(2)
 End;
 If LicenseFile<>'' Then Begin
  If Extension(LicenseFile)<>'.CSM' Then ExternalRun(LicenseFile,True);
  LoadModel(LicenseFile); WriteLn('Modele CSM autonome : aucune licence COMSOL requise.');
  Halt(0);
 End;
 If InputFile<>'' Then LoadModel(InputFile);
 If (Study<>'') And (Study<>'std1') Then Fail('Etude autonome disponible : std1');
 If (Job<>'') And (Job<>'sol1') Then Fail('Tache autonome disponible : sol1');
 If (Method<>'') And (Method<>'reset') And (Method<>'mesh') And (Method<>'solve')
 Then Fail('Methodes : reset, mesh, solve');
 If Method='reset' Then NewModel;
 ReadParams; ApplyLists;
 If ClearMeshOpt Then Begin
  MeshReady:=False; Invalidate
 End;
 If ClearSolOpt Then Invalidate;
 HasBatch:=BatchMode Or (InputFile<>'') Or (OutputFile<>'') Or (Method<>'') Or (Study<>'')
 Or (Job<>'');
 If HasBatch Then Begin
  If Method='mesh' Then Begin
   MeshReady:=True; Log('Maillage construit')
  End Else Solve(False);
  If Not NoSave Then Begin
   If OutputFile='' Then OutputFile:='RESULTAT.CSM';
   If Extension(OutputFile)<>'.CSM' Then Fail('Sortie autonome : extension .csm requise');
   SaveModel(OutputFile);
  End;
  If Not Graphics Then Begin
   If Not Converged And (Method<>'mesh') Then Halt(3) Else Halt(0)
  End;
 End;
 OpenGraphics; Draw;
 Repeat
 Poll; If (MB And 1<>0) And (OldB And 1=0) Then Begin
  Click; Draw
 End;
 OldB:=MB; If KeyPressed Then Begin
  Key; Draw
 End; Delay(10);
 Until Quit;
 Mouse(False); CloseGraph;
END.
