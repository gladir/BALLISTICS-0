{ @author: Sylvain Maltais
  Interface francaise inspiree de COMSOL, TP7 / FPC 3.2.
  Solveur autonome 2D differences finies, pas le moteur COMSOL.
  Format natif texte CSM; MPH/classes delegues a COMSOL_BATCH. }
program COMSOL;
{$IFDEF FPC}{$MODE TP}{$ENDIF}
uses {$IFDEF FPC}Crt,PtcGraph,PtcCrt,PtcMouse,Dos{$ELSE}Crt,Graph,Dos{$ENDIF};
const
 MaxN=40; NP=10;
 Names:array[1..NP] of string[12]=('largeur','hauteur','conductivite','source',
 'gauche','droite','bas','haut','tolerance','iterations');
 Captions:array[1..NP] of string[24]=('Largeur (m)','Hauteur (m)',
 'Conductivite (W/mK,S/m)','Source (W/m3,A/m3)','Bord gauche (K,V)',
 'Bord droit (K,V)','Bord bas (K,V)','Bord haut (K,V)',
 'Tolerance absolue','Iterations maximales');
 Defaults:array[1..NP] of real=(0.1,0.1,10,0,350,300,300,300,0.0001,5000);
 Nodes:array[1..11] of string[26]=('Modele 1','  Definitions','    Parametres',
 '  Composant 1 (2D)','    Geometrie : rectangle','    Materiau homogene',
 '    Physique','    Conditions aux limites','    Maillage structure',
 '  Etude stationnaire std1','  Resultats');
 MenuNames:array[1..7] of string[10]=('Fichier','Modele','Physique','Maillage','Etude','Resultats','Aide');
var
 P:array[1..NP] of real;
 U:array[0..MaxN,0..MaxN] of real;
 N,Physics,Selected,Field,Menu,MenuRow,View,Iter:integer;
 MeshReady,Solved,Converged,Cancelled,Quit,GraphOpen,ShowMesh:boolean;
 InputFile,OutputFile,LogFile,Study,Job,Method,ParamFile,PNam,PList,PIndex,LicenseFile:string;
 NoSave,Graphics,LogOut,ClearMeshOpt,ClearSolOpt,CancelOpt,Testing,BatchMode:boolean;
 Alive:real; Status,ModelFile:string; Residual:real;
 MX,MY,MB,OldB:integer;

function Upper(S:string):string;
var I:integer;
begin for I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S end;
function F(V:real; D:integer):string;
var S:string;
begin Str(V:0:D,S); F:=S end;
procedure Console;
begin {$IFDEF FPC}Assign(Output,''); Rewrite(Output);{$ENDIF} end;
procedure Fail(S:string);
begin
 if GraphOpen then CloseGraph;
 Console; WriteLn('Erreur : ',S); Halt(1);
end;
procedure Log(S:string);
var T:Text; E:integer;
begin
 Status:=S;
 if LogOut and not GraphOpen then WriteLn(S);
 if LogFile='' then Exit;
 Assign(T,LogFile); {$I-}Append(T); E:=IOResult;
 if E<>0 then begin Rewrite(T); E:=IOResult end;
 if E=0 then begin WriteLn(T,S); E:=IOResult; Close(T); if IOResult<>0 then E:=1 end;
 {$I+} if E<>0 then Fail('Impossible d''ecrire le journal '+LogFile);
end;
function Extension(S:string):string;
var D:DirStr; A:NameStr; E:ExtStr;
begin FSplit(S,D,A,E); Extension:=Upper(E) end;
function Valid(I:integer; V:real):boolean;
begin
 Valid:=False;
 case I of
 1,2:Valid:=(V>=0.000001) and (V<=10000);
 3:Valid:=(V>=0.000001) and (V<=1000000);
 4..8:Valid:=(V>=-1.0E9) and (V<=1.0E9);
 9:Valid:=(V>=1.0E-10) and (V<=1);
 10:Valid:=(V>=1) and (V<=30000) and (V=Trunc(V));
 end;
end;
procedure Invalidate;
begin Solved:=False; Converged:=False; Iter:=0 end;
procedure NewModel;
var I:integer;
begin
 for I:=1 to NP do P[I]:=Defaults[I];
 N:=20; Physics:=0; MeshReady:=False; Invalidate; Cancelled:=False;
 ModelFile:='Sans titre.csm'; Selected:=1; Field:=1; View:=0; ShowMesh:=True;
 Status:='Nouveau modele : conduction thermique stationnaire';
end;
procedure Help;
begin
 Console;
 WriteLn('COMSOL - Interface graphique et solveur autonome 2D');
 WriteLn('Utilisation : COMSOL [batch] [options]');
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
end;
function ArgValue(var I:integer):string;
begin Inc(I); if I>ParamCount then Fail('Valeur manquante pour '+ParamStr(I-1)); ArgValue:=ParamStr(I) end;
function Number(S:string):real;
var V:real; E:integer;
begin
 Val(S,V,E); if E<>0 then Fail('Nombre invalide : '+S);
 if (V<>V) or (Abs(V)>1.0E12) then Fail('Nombre hors limites'); Number:=V;
end;
procedure Parse;
var I:integer; A,S:string;
begin
 I:=1;
 while I<=ParamCount do begin
 A:=Upper(ParamStr(I));
 if (A='/?') or (A='-HELP') or (A='--HELP') then begin Help; Halt(0) end
 else if (A='/TEST') then Testing:=True
 else if A='BATCH' then BatchMode:=True
 else if A='-INPUTFILE' then InputFile:=ArgValue(I)
 else if A='-OUTPUTFILE' then OutputFile:=ArgValue(I)
 else if A='-STUDY' then Study:=ArgValue(I)
 else if A='-JOB' then Job:=ArgValue(I)
 else if A='-METHODCALL' then Method:=ArgValue(I)
 else if A='-BATCHLOG' then LogFile:=ArgValue(I)
 else if A='-BATCHLOGOUT' then LogOut:=True
 else if A='-ALIVETIME' then begin S:=ArgValue(I); Alive:=Number(S); if Alive<=0 then Fail('Intervalle positif requis') end
 else if A='-CHECKLICENSE' then LicenseFile:=ArgValue(I)
 else if A='-CLEARMESH' then ClearMeshOpt:=True
 else if (A='-CLEARSOLUTION') or (A='-CLEARSOL') then ClearSolOpt:=True
 else if A='-GRAPHICS' then Graphics:=True
 else if A='-NOSAVE' then NoSave:=True
 else if A='-PARAMFILE' then ParamFile:=ArgValue(I)
 else if A='-PNAME' then PNam:=ArgValue(I)
 else if A='-PLIST' then PList:=ArgValue(I)
 else if A='-PINDEX' then PIndex:=ArgValue(I)
 else if A='-CANCEL' then CancelOpt:=True
 else Fail('Option inconnue : '+ParamStr(I));
 Inc(I);
 end;
end;
function Trim(S:string):string;
begin
 while (Length(S)>0) and (S[1]<=' ') do Delete(S,1,1);
 while (Length(S)>0) and (S[Length(S)]<=' ') do Delete(S,Length(S),1);
 Trim:=S;
end;
function Token(var S:string):string;
var I:integer;
begin
 I:=Pos(',',S); if I=0 then begin Token:=Trim(S); S:='' end
 else begin Token:=Trim(Copy(S,1,I-1)); Delete(S,1,I) end;
end;
procedure SetParam(Name,Value:string);
var I:integer; V:real;
begin
 Name:=Upper(Trim(Name)); V:=Number(Trim(Value));
 if Name='N' then begin
 if (V<4) or (V>MaxN) or (V<>Trunc(V)) then Fail('n doit etre entier entre 4 et 40');
 N:=Round(V); MeshReady:=False; Invalidate; Exit end;
 if Name='PHYSIQUE' then begin
 if (V<>0) and (V<>1) then Fail('physique doit valoir 0 ou 1');
 Physics:=Round(V); Invalidate; Exit end;
 for I:=1 to NP do if Upper(Names[I])=Name then begin
 if not Valid(I,V) then Fail('Parametre hors limites : '+Name);
 P[I]:=V; Invalidate; Exit end;
 Fail('Parametre inconnu : '+Name);
end;
function Chosen(Index:integer):boolean;
var S,T:string; V:real;
begin
 Chosen:=PIndex=''; S:=PIndex;
 while S<>'' do begin T:=Token(S); V:=Number(T);
 if (V<1) or (V<>Trunc(V)) then Fail('Indice de parametre invalide');
 if V=Index then Chosen:=True;
 end;
end;
procedure ReadParams;
var T:Text; S:string; I,Idx,E:integer;
begin
 if ParamFile='' then begin if PIndex<>'' then Fail('-pindex exige -paramfile'); Exit end;
 Assign(T,ParamFile); {$I-}Reset(T); E:=IOResult;{$I+}
 if E<>0 then Fail('Impossible de lire '+ParamFile);
 Idx:=0;
 while not Eof(T) do begin
 ReadLn(T,S); S:=Trim(S);
 if (S<>'') and (S[1]<>'#') then begin
 Inc(Idx); I:=Pos('=',S); if I=0 then Fail('Ligne attendue : nom=valeur');
 if Chosen(Idx) then SetParam(Copy(S,1,I-1),Copy(S,I+1,255));
 end;
 end;
 Close(T);
 S:=PIndex; while S<>'' do if Number(Token(S))>Idx then Fail('Indice absent du fichier');
end;
procedure ApplyLists;
var A,B,Name,Value:string;
begin
 A:=PNam; B:=PList;
 while (A<>'') or (B<>'') do begin
 Name:=Token(A); Value:=Token(B);
 if (Name='') or (Value='') then Fail('-pname et -plist : nombres de valeurs differents');
 SetParam(Name,Value);
 end;
end;
procedure SaveModel(Name:string);
var T:Text; I,J,E:integer;
begin
 if Extension(Name)<>'.CSM' then begin Log('Enregistrer avec extension .csm uniquement'); Exit end;
 Assign(T,Name); {$I-}Rewrite(T); E:=IOResult;
 if E=0 then begin
 WriteLn(T,'PASCAL-COMSOL 1'); WriteLn(T,N,' ',Physics);
 for I:=1 to NP do WriteLn(T,P[I]:0:12);
 WriteLn(T,Ord(MeshReady),' ',Ord(Solved),' ',Ord(Converged),' ',Iter,' ',Residual:0:12);
 if Solved then for J:=0 to N do for I:=0 to N do WriteLn(T,U[I,J]:0:12);
 E:=IOResult; Close(T); if IOResult<>0 then E:=1;
 end;{$I+}
 if E<>0 then Fail('Echec enregistrement '+Name);
 ModelFile:=Name; Log('Modele enregistre : '+Name);
end;
procedure LoadModel(Name:string);
var T:Text; Magic:string; I,J,E,A,B,C,NN,Ph,It:integer;
 Q:array[1..NP] of real; R:real; Good:boolean;
begin
 if Extension(Name)<>'.CSM' then begin
 Log('MPH/classe : utiliser -inputfile avec COMSOL_BATCH configure'); Exit end;
 Assign(T,Name); {$I-}Reset(T); E:=IOResult;{$I+}
 if E<>0 then Fail('Impossible de lire '+Name);
 {$I-}
 ReadLn(T,Magic); E:=IOResult; Good:=(E=0) and (Magic='PASCAL-COMSOL 1');
 ReadLn(T,NN,Ph); E:=IOResult;
 Good:=Good and (E=0) and (NN>=4) and (NN<=MaxN) and (Ph>=0) and (Ph<=1);
 for I:=1 to NP do begin ReadLn(T,Q[I]); E:=IOResult; if E<>0 then Good:=False else if not Valid(I,Q[I]) then Good:=False end;
 ReadLn(T,A,B,C,It,R); E:=IOResult;
 Good:=Good and (E=0) and (A>=0) and (A<=1) and (B>=0) and (B<=1) and (C>=0) and (C<=1) and (It>=0) and (It<=30000);
 if not Good then begin Close(T); E:=IOResult; {$I+}Fail('Format CSM invalide') end;
 {$I-}
 if B=1 then for J:=0 to NN do for I:=0 to NN do begin
 ReadLn(T,U[I,J]); E:=IOResult;
 if E<>0 then Good:=False else if (U[I,J]<>U[I,J]) or (Abs(U[I,J])>1.0E30) then Good:=False;
 end;
 Close(T); E:=IOResult;{$I+}
 if not Good then Fail('Solution CSM incomplete ou invalide');
 N:=NN; Physics:=Ph; for I:=1 to NP do P[I]:=Q[I];
 MeshReady:=A=1; Solved:=B=1; Converged:=C=1; Iter:=It; Residual:=R;
 ModelFile:=Name; Log('Modele charge : '+Name);
end;
function Seconds:real;
var H,M,S,HS:word;
begin GetTime(H,M,S,HS); Seconds:=H*3600.0+M*60.0+S+HS/100.0 end;
procedure Solve(Interactive:boolean);
var I,J:integer; AX,AY,V,D,Last,NowT:real; C:char;
begin
 MeshReady:=True; Invalidate; Cancelled:=False;
 for J:=0 to N do for I:=0 to N do U[I,J]:=(P[5]+P[6]+P[7]+P[8])/4;
 for I:=0 to N do begin U[I,0]:=P[7]; U[I,N]:=P[8] end;
 for J:=0 to N do begin U[0,J]:=P[5]; U[N,J]:=P[6] end;
 AX:=Sqr(N/P[1]); AY:=Sqr(N/P[2]); Last:=Seconds;
 Log('Calcul stationnaire : std1 / sol1');
 repeat
 Inc(Iter); Residual:=0;
 for J:=1 to N-1 do for I:=1 to N-1 do begin
 V:=(AX*(U[I-1,J]+U[I+1,J])+AY*(U[I,J-1]+U[I,J+1])+P[4]/P[3])/(2*(AX+AY));
 D:=Abs(V-U[I,J]); if D>Residual then Residual:=D; U[I,J]:=V;
 end;
 if Interactive and KeyPressed then begin C:=ReadKey;
 if C=#0 then C:=ReadKey else if C=#27 then Cancelled:=True end;
 NowT:=Seconds; if NowT<Last then Last:=Last-86400;
 if NowT-Last>=Alive then begin Log('Iteration '+F(Iter,0)+' ; variation '+F(Residual,8)); Last:=NowT end;
 until (Residual<P[9]) or (Iter>=Round(P[10])) or Cancelled;
 Converged:=(Residual<P[9]) and not Cancelled; Solved:=not Cancelled;
 if Cancelled then Log('Calcul annule par Echap')
 else if Converged then Log('Convergence en '+F(Iter,0)+' iterations')
 else Log('Limite atteinte : solution non convergee');
end;
procedure Mouse(Show:boolean);
{$IFNDEF FPC}var R:Registers;{$ENDIF}
begin
 {$IFDEF FPC}if Show then PtcMouse.ShowMouse else PtcMouse.HideMouse;
 {$ELSE}if Show then R.AX:=1 else R.AX:=2; Intr($33,R);{$ENDIF}
end;
procedure Poll;
{$IFDEF FPC}var X,Y,B:longint;{$ELSE}var R:Registers;{$ENDIF}
begin
 {$IFDEF FPC}PtcMouse.GetMouseState(X,Y,B); MX:=X; MY:=Y; MB:=B;
 {$ELSE}R.AX:=3; Intr($33,R); MX:=R.CX; MY:=R.DX; MB:=R.BX;{$ENDIF}
end;
procedure Box(X,Y,R,B,C:integer);
begin SetFillStyle(SolidFill,C); Bar(X,Y,R,B) end;
procedure Txt(X,Y,C:integer; S:string);
begin SetColor(C); OutTextXY(X,Y,S) end;
function Count(M:integer):integer;
begin case M of 1:Count:=6;2:Count:=2;3:Count:=2;4:Count:=3;5:Count:=3;6:Count:=4;else Count:=2 end end;
function Item(M,R:integer):string;
begin
 Item:='';
 case M of
 1:case R of 1:Item:='Nouveau modele';2:Item:='Ouvrir CSM';3:Item:='Enregistrer CSM';4:Item:='Executer MPH externe';5:Item:='Exporter tableau CSV';6:Item:='Quitter' end;
 2:case R of 1:Item:='Modifier le parametre';2:Item:='Parametre suivant' end;
 3:case R of 1:Item:='Conduction thermique';2:Item:='Potentiel electrique' end;
 4:case R of 1:Item:='Construire le maillage';2:Item:='Nombre de subdivisions';3:Item:='Effacer le maillage' end;
 5:case R of 1:Item:='Calculer std1 (F5)';2:Item:='Effacer la solution';3:Item:='Initialiser les valeurs' end;
 6:case R of 1:Item:='Champ scalaire';2:Item:='Maillage';3:Item:='Flux / courant';4:Item:='Geometrie' end;
 7:case R of 1:Item:='Commandes';2:Item:='Modele et limites' end;
 end;
end;
procedure Limits(var Lo,Hi:real);
var I,J:integer;
begin
 Lo:=U[0,0]; Hi:=Lo;
 for J:=0 to N do for I:=0 to N do begin
 if U[I,J]<Lo then Lo:=U[I,J]; if U[I,J]>Hi then Hi:=U[I,J] end;
end;
procedure Draw;
const Palette:array[0..7] of integer=(Blue,LightBlue,Cyan,LightCyan,Green,Yellow,LightRed,Red);
var I,J,X,Y,C,R,B,Idx:integer; Lo,Hi,V,DX,DY,L:real; S:string;
begin
 Mouse(False); Box(0,0,639,479,LightGray);
 Box(0,0,639,19,Blue);
 for I:=1 to 7 do Txt((I-1)*90+3,6,White,MenuNames[I]);
 Box(0,21,639,43,White); Txt(5,28,Blue,'[Nouveau]  [Ouvrir]  [Enregistrer]  [Mailler]  [Calculer F5]');
 Box(2,46,181,420,White); Box(185,46,383,420,White); Box(387,46,637,355,White);
 Txt(7,54,Blue,'Arbre du modele'); Txt(190,54,Blue,'Reglages'); Txt(393,54,Blue,'Graphiques');
 for I:=1 to 11 do begin
 if Selected=I then begin Box(4,70+(I-1)*18,179,86+(I-1)*18,Blue); C:=White end else C:=Black;
 S:=Nodes[I]; if I=7 then if Physics=0 then S:='    Transfert thermique' else S:='    Courants electriques';
 Txt(6,75+(I-1)*18,C,Copy(S,1,21));
 end;
 Txt(7,285,Black,'Rectangle 2D'); Txt(7,303,Black,F(P[1],3)+' x '+F(P[2],3)+' m');
 Txt(7,325,Black,'Noeuds : '+F(Sqr(N+1),0));
 if MeshReady then S:='Construit' else S:='Non construit'; Txt(7,343,Black,S);
 for I:=1 to NP do begin
 Y:=73+(I-1)*31; Txt(190,Y,Black,Copy(Captions[I],1,23));
 if Field=I then C:=Blue else C:=DarkGray;
 Box(190,Y+10,378,Y+25,C); Txt(195,Y+14,White,F(P[I],6));
 end;
 Txt(190,390,Black,'Cliquer pour modifier');
 Txt(393,75,Black,'x (m) / y (m)');
 Lo:=0; Hi:=1; if Solved then Limits(Lo,Hi);
 for J:=0 to N-1 do for I:=0 to N-1 do begin
 X:=403+I*205 div N; R:=403+(I+1)*205 div N;
 Y:=325-(J+1)*205 div N; B:=325-J*205 div N;
 C:=LightGray;
 if Solved and (View<>1) and (View<>3) then begin
 V:=(U[I,J]+U[I+1,J]+U[I,J+1]+U[I+1,J+1])/4;
 if Hi-Lo>1.0E-20 then Idx:=Round((V-Lo)/(Hi-Lo)*7) else Idx:=3;
 if Idx<0 then Idx:=0; if Idx>7 then Idx:=7; C:=Palette[Idx];
 end;
 Box(X,Y,R,B,C);
 end;
 SetColor(Black); Rectangle(403,120,608,325);
 if (View=1) or (ShowMesh and (View<>3) and MeshReady) then begin
 SetColor(DarkGray);
 for I:=0 to N do begin X:=403+I*205 div N; Line(X,120,X,325); Y:=325-I*205 div N; Line(403,Y,608,Y) end;
 end;
 if Solved and (View=2) then begin
 SetColor(Black);
 for J:=2 to N-2 do if J mod 3=0 then for I:=2 to N-2 do if I mod 3=0 then begin
 DX:=-(U[I+1,J]-U[I-1,J])*N/P[1]/2;
 DY:=-(U[I,J+1]-U[I,J-1])*N/P[2]/2; L:=Sqrt(DX*DX+DY*DY);
 if L>1.0E-20 then begin
 X:=403+I*205 div N; Y:=325-J*205 div N;
 R:=X+Round(DX/L*9); B:=Y-Round(DY/L*9); Line(X,Y,R,B); Circle(R,B,1);
 end end;
 end;
 if Solved then begin
 Txt(393,88,Blue,'Min '+F(Lo,3)); Txt(393,102,Red,'Max '+F(Hi,3));
 for I:=0 to 7 do Box(615,120+(7-I)*25,628,144+(7-I)*25,Palette[I]);
 end;
 Txt(403,334,Black,'0        '+F(P[1],3)+' m');
 Box(387,360,637,453,White); Txt(392,367,Blue,'Messages / Progression');
 Txt(392,386,Black,'Iterations : '+F(Iter,0));
 Txt(392,401,Black,'Variation : '+F(Residual,7));
 if Solved then if Converged then S:='Solution convergee' else S:='NON CONVERGE' else S:='Aucune solution';
 Txt(392,418,Black,S); Txt(392,437,Blue,'Echap pendant calcul : annuler');
 Txt(6,434,Black,Copy(ModelFile,1,46));
 Box(0,459,639,479,Blue); Txt(4,466,White,Copy(Status,1,78));
 if Menu>0 then begin
 X:=(Menu-1)*90; if X>404 then X:=404;
 Box(X,20,X+234,22+Count(Menu)*20,LightGray);
 for I:=1 to Count(Menu) do begin
 if MenuRow=I then begin Box(X,22+(I-1)*20,X+234,41+(I-1)*20,Blue); C:=White end else C:=Black;
 Txt(X+4,27+(I-1)*20,C,Item(Menu,I));
 end end;
 Mouse(True);
end;
function Ask(Title,Initial:string):string;
var S:string; C:char; Stop:boolean;
begin
 Mouse(False); S:=Initial; Stop:=False;
 repeat
 Box(35,190,605,275,LightGray); Txt(45,202,Black,Title);
 Box(45,222,595,245,White); Txt(49,230,Black,Copy(S,1,65)+'_');
 Txt(45,257,Black,'Entree valider ; Echap annuler ; Retour effacer'); C:=ReadKey;
 case C of
 #0:C:=ReadKey;
 #27:begin S:=''; Stop:=True end;
 #13:Stop:=True;
 #8:if Length(S)>0 then Delete(S,Length(S),1);
 else if (C>=' ') and (Length(S)<200) then S:=S+C;
 end;
 until Stop; Mouse(True); Ask:=S;
end;
procedure Notice(A,B:string);
var C:char;
begin
 Mouse(False); Box(15,185,625,280,LightGray);
 Txt(25,202,Black,A); Txt(25,224,Black,B); Txt(25,255,Black,'Appuyez sur une touche...');
 C:=ReadKey; if C=#0 then C:=ReadKey; Mouse(True);
end;
procedure Edit;
var S:string; V:real; E:integer;
begin
 S:=Ask(Captions[Field],F(P[Field],6)); if S='' then Exit;
 Val(S,V,E);
 if E=0 then if Valid(Field,V) then begin P[Field]:=V; Invalidate; Status:='Parametre modifie'; Exit end;
 Status:='Valeur invalide ou hors limites';
end;
procedure ExportCSV(Name:string);
var T:Text; I,J,E:integer; QX,QY:real;
begin
 if not Solved then begin Log('Calculer avant export'); Exit end;
 Assign(T,Name); {$I-}Rewrite(T); E:=IOResult;
 if E=0 then begin
 WriteLn(T,'x_m;y_m;champ;flux_x;flux_y');
 for J:=1 to N-1 do for I:=1 to N-1 do begin
 QX:=-P[3]*(U[I+1,J]-U[I-1,J])*N/(2*P[1]);
 QY:=-P[3]*(U[I,J+1]-U[I,J-1])*N/(2*P[2]);
 WriteLn(T,F(I*P[1]/N,8),';',F(J*P[2]/N,8),';',F(U[I,J],8),';',F(QX,8),';',F(QY,8));
 end;
 E:=IOResult; Close(T); if IOResult<>0 then E:=1;
 end;{$I+}
 if E<>0 then Fail('Export CSV impossible'); Log('Tableau exporte : '+Name);
end;
function Quoted(S:string):string;
begin
 if Pos('"',S)>0 then Fail('Guillemet interdit dans un argument externe');
 Quoted:='"'+S+'"';
end;
procedure ExternalRun(FileName:string; FromCLI:boolean);
var Engine,Args,A:string; I,Code:integer;
begin
 Engine:=GetEnv('COMSOL_BATCH');
 if Engine='' then begin
 if FromCLI then Fail('MPH/classe : definir COMSOL_BATCH vers comsolbatch.exe')
 else begin Notice('MPH exige le moteur COMSOL installe.', 'Definir COMSOL_BATCH vers comsolbatch.exe.'); Exit end;
 end;
 Args:='';
 if FromCLI then begin
 for I:=1 to ParamCount do begin A:=ParamStr(I);
 if Upper(A)<>'BATCH' then begin
 if Length(Args)+Length(A)+3>240 then Fail('Arguments externes trop longs pour TP7');
 Args:=Args+Quoted(A)+' ';
 end;
 end;
 end else Args:='-inputfile '+Quoted(FileName);
 if GraphOpen then begin Mouse(False); CloseGraph; GraphOpen:=False end;
 SwapVectors; Exec(Engine,Args); SwapVectors; Code:=DosError;
 if Code<>0 then Fail('Impossible de lancer COMSOL_BATCH : '+F(Code,0));
 Code:=DosExitCode; Console; WriteLn('Moteur COMSOL termine, code : ',Code);
 Halt(Code);
end;
procedure Action(M,R:integer);
var S:string; V:real; E:integer;
begin
 Menu:=0;
 case M of
 1:case R of
 1:NewModel;
 2:begin S:=Ask('Ouvrir modele texte .csm','MODELE.CSM'); if S<>'' then LoadModel(S) end;
 3:begin S:=Ask('Enregistrer modele .csm',ModelFile); if S<>'' then SaveModel(S) end;
 4:begin S:=Ask('Executer avec moteur COMSOL externe','MODELE.MPH'); if S<>'' then ExternalRun(S,False) end;
 5:begin S:=Ask('Exporter resultats CSV','RESULTAT.CSV'); if S<>'' then ExportCSV(S) end;
 6:Quit:=True;
 end;
 2:if R=1 then Edit else begin Inc(Field); if Field>NP then Field:=1 end;
 3:begin Physics:=R-1; Invalidate end;
 4:case R of
 1:begin MeshReady:=True; Status:='Maillage structure construit' end;
 2:begin
 S:=Ask('Subdivisions par axe (4..40)',F(N,0)); Val(S,V,E);
 if E=0 then if (V>=4) and (V<=MaxN) and (V=Trunc(V)) then begin N:=Round(V); MeshReady:=False; Invalidate end;
 end;
 3:begin MeshReady:=False; Invalidate end;
 end;
 5:case R of
 1:begin Status:='Calcul en cours... Echap annule'; Draw; Mouse(False); Solve(True); Mouse(True) end;
 2:Invalidate;
 3:NewModel;
 end;
 6:View:=R-1;
 7:if R=1 then Notice('F10 menus, fleches, Entree ; F5 calcul ; Tab champ.', 'Arbre et champs cliquables ; Echap quitte ou annule.')
 else Notice('Solveur 2D : -div(k grad u) = source, bords fixes.', 'MPH natif : moteur externe ; fichiers autonomes .csm.');
 end;
end;
procedure Click;
var X,R:integer;
begin
 if MY<20 then begin Menu:=MX div 90+1; if Menu>7 then Menu:=7; MenuRow:=1; Exit end;
 if Menu>0 then begin
 X:=(Menu-1)*90; if X>404 then X:=404; R:=(MY-22) div 20+1;
 if (MY>=22) and (MX>=X) and (MX<=X+234) and (R>=1) and (R<=Count(Menu)) then Action(Menu,R) else Menu:=0;
 Exit end;
 if (MY>=21) and (MY<=43) then begin
 if MX<85 then Action(1,1) else if MX<165 then Action(1,2)
 else if MX<290 then Action(1,3) else if MX<380 then Action(4,1) else Action(5,1); Exit end;
 if (MX<182) and (MY>=70) and (MY<268) then begin
 Selected:=(MY-70) div 18+1;
 case Selected of 3:Field:=1;5:begin Field:=1; View:=3 end;
 6:Field:=3;7:Field:=4;8:Field:=5;9:View:=1;10:Field:=9;11:View:=0 end;
 end;
 if (MX>=185) and (MX<=383) and (MY>=73) and (MY<383) then begin Field:=(MY-73) div 31+1; Edit end;
end;
procedure Key;
var C:char;
begin
 C:=ReadKey;
 if C=#0 then begin
 C:=ReadKey;
 if C=#63 then Action(5,1)
 else if C=#59 then Action(7,1)
 else if C=#68 then begin Menu:=1; MenuRow:=1 end
 else if Menu>0 then case C of
 #75:begin Dec(Menu); if Menu<1 then Menu:=7; MenuRow:=1 end;
 #77:begin Inc(Menu); if Menu>7 then Menu:=1; MenuRow:=1 end;
 #72:begin Dec(MenuRow); if MenuRow<1 then MenuRow:=Count(Menu) end;
 #80:begin Inc(MenuRow); if MenuRow>Count(Menu) then MenuRow:=1 end;
 end
 else case C of
 #72:if Selected>1 then Dec(Selected);
 #80:if Selected<11 then Inc(Selected);
 end;
 end else case C of
 #27:if Menu>0 then Menu:=0 else Quit:=True;
 #13:if Menu>0 then Action(Menu,MenuRow) else Edit;
 #9:begin Inc(Field); if Field>NP then Field:=1 end;
 end;
end;
procedure OpenGraphics;
var D,M,E:integer;
begin
 {$IFDEF FPC}D:=VGA; M:=VGAHi;{$ELSE}D:=Detect; M:=0;{$ENDIF}
 InitGraph(D,M,''); E:=GraphResult;
 if E<>grOk then Fail(GraphErrorMsg(E)); GraphOpen:=True;
 {$IFDEF FPC}PtcMouse.InitMouse;{$ENDIF} Mouse(True);
end;
procedure Check(B:boolean; S:string);
begin if not B then Fail('TEST : '+S) end;
procedure Tests;
var I,J:integer; Error:real;
begin
 NewModel;
 for I:=5 to 8 do P[I]:=300;
 Solve(False); Check(Converged,'champ constant convergence');
 for J:=0 to N do for I:=0 to N do Check(Abs(U[I,J]-300)<1.0E-8,'champ constant');
 NewModel; N:=16; P[1]:=1; P[2]:=1; P[3]:=1; P[4]:=1;
 for I:=5 to 8 do P[I]:=0;
 P[9]:=1.0E-8; Solve(False);
 Check(Converged,'Poisson convergence'); Check(U[8,8]>0,'source positive');
 Error:=0;
 for J:=1 to N-1 do for I:=1 to N-1 do
 if Abs((4*U[I,J]-U[I-1,J]-U[I+1,J]-U[I,J-1]-U[I,J+1])*Sqr(N)-1)>Error then
 Error:=Abs((4*U[I,J]-U[I-1,J]-U[I+1,J]-U[I,J-1]-U[I,J+1])*Sqr(N)-1);
 Check(Error<0.0001,'residu equation');
 Check(Abs(U[4,8]-U[12,8])<0.00001,'symetrie');
 P[10]:=1; Solve(False); Check(not Converged,'non convergence signalee');
 WriteLn('OK : champ constant, Poisson, residu, symetrie, limite iterations.');
end;
var HasBatch:boolean;
begin
 Console; NewModel; Alive:=10; OldB:=0; Quit:=False; Menu:=0;
 GraphOpen:=False; Parse;
 if Testing then begin Tests; Halt(0) end;
 if InputFile<>'' then if Extension(InputFile)<>'.CSM' then ExternalRun(InputFile,True);
 if CancelOpt then begin LogOut:=True; Log('Execution annulee avant calcul (aucun processus distant arrete)'); Halt(2) end;
 if LicenseFile<>'' then begin
 if Extension(LicenseFile)<>'.CSM' then ExternalRun(LicenseFile,True);
 LoadModel(LicenseFile); WriteLn('Modele CSM autonome : aucune licence COMSOL requise.'); Halt(0);
 end;
 if InputFile<>'' then LoadModel(InputFile);
 if (Study<>'') and (Study<>'std1') then Fail('Etude autonome disponible : std1');
 if (Job<>'') and (Job<>'sol1') then Fail('Tache autonome disponible : sol1');
 if (Method<>'') and (Method<>'reset') and (Method<>'mesh') and (Method<>'solve') then Fail('Methodes : reset, mesh, solve');
 if Method='reset' then NewModel;
 ReadParams; ApplyLists;
 if ClearMeshOpt then begin MeshReady:=False; Invalidate end;
 if ClearSolOpt then Invalidate;
 HasBatch:=BatchMode or (InputFile<>'') or (OutputFile<>'') or (Method<>'') or (Study<>'') or (Job<>'');
 if HasBatch then begin
 if Method='mesh' then begin MeshReady:=True; Log('Maillage construit') end else Solve(False);
 if not NoSave then begin
 if OutputFile='' then OutputFile:='RESULTAT.CSM';
 if Extension(OutputFile)<>'.CSM' then Fail('Sortie autonome : extension .csm requise'); SaveModel(OutputFile);
 end;
 if not Graphics then begin if not Converged and (Method<>'mesh') then Halt(3) else Halt(0) end;
 end;
 OpenGraphics; Draw;
 repeat
 Poll; if (MB and 1<>0) and (OldB and 1=0) then begin Click; Draw end;
 OldB:=MB; if KeyPressed then begin Key; Draw end; Delay(10);
 until Quit;
 Mouse(False); CloseGraph;
end.
