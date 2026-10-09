{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/ballistics-0)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2) }

Program BALISTIC;

{ Turbo Pascal 7 / Free Pascal (-Mtp). SI units except diameter (mm),
  temperature (C), pressure (hPa), humidity (%), angles (degrees).
  Educational point-mass model: Cd = 0.30 / BC, NOT a G1/G7 drag table.
  ALT is elevation above sea level; launch and impact are at local y=0.
  Wind direction: 0 = tailwind, 180 = headwind; transverse component
  is ignored by this two-dimensional model. No persistent settings. }

Const
 Gravity = 9.80665;
 PiValue = 3.141592653589793;

Type
 State = Record
  x,y,vx,vy,t: Real
 End;

Var
 Cmd, Model, Fmt, Arg, Key, Value: String;
 V0, Angle, BC, Mass, Diameter, Alt, Step, Dist, First, Last: Real;
 Temp, Pressure, Humidity, Wind, Direction, Rho, WindX, Drag: Real;
 DirectSpeed: Real;
 Optimize, HasSpeed, HasV0, HasDist, HasTemp, HasPressure: Boolean;
 S, TargetState, PreviousState, SampleState: State;
 Peak, BestRange, BestAngle, A: Real;
 I, P: Integer;

Procedure Fail(Msg: String);Begin
 WriteLn('Erreur: ',Msg);
 Halt(1)
End;

Function Upper(S: String): String;
Var
 J: Integer;
Begin
 For J:=1 To Length(S) Do S[J]:=UpCase(S[J]);
 Upper:=S
End;

Function Number(S: String): Real;
Var
 N: Real;
 E: Integer;
 J: Integer;
Begin
 If Length(S)=0 Then Fail('Valeur numerique manquante');
 For J:=1 To Length(S) Do    If Not (S[J] In ['0'..'9','+','-','.','e','E'])
 Then      Fail('Nombre invalide: '+S);
 Val(S,N,E);
 If E<>0 Then Fail('Nombre invalide: '+S);
 If Abs(N)>1.0E8 Then Fail('Nombre hors limites');
 Number:=N
End;

Procedure Help;Begin
 WriteLn('BALISTIC - Cette commande permet de simuler un moteur balistique simplifi'+#130+'.');
 WriteLn;
 WriteLn('Syntaxe: BALISTIC TRAJECTORY|VELOCITY|ENERGY|RANGE|TABLE|ATMOSPHERE');
 WriteLn;
 WriteLn('Unites: m, m/s, kg, mm (diametre), degres, secondes, joules.');
 WriteLn('Options de vol: /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010');
 WriteLn(' /DIAMETER:7.62 /ALT:0 /ATM:STANDARD');
 WriteLn;
 WriteLn('TRAJECTORY: /STEP:100 (jusqu''a impact)');
 WriteLn;
 WriteLn('VELOCITY: /DIST:500');
 WriteLn;
 WriteLn('ENERGY: /VELOCITY:800 /MASS:0.010 ou options de vol /DIST:500');
 WriteLn;
 WriteLn('RANGE: /ANGLE:45 ou /OPTIMIZE (precision 0.1 degre)');
 WriteLn;
 WriteLn('TABLE: /START:0 /END:1000 /STEP:100 /FORMAT:TEXT|CSV|JSON');
 WriteLn('Atmosphere commune: /ATM:STANDARD|ISA|ICAO|CUSTOM|VACUUM');
 WriteLn; 
 WriteLn('ATMOSPHERE: /MODEL:STANDARD /ALT:1000 /TEMP:15');
 WriteLn;
 WriteLn(' /PRESSURE:898.7 /HUMIDITY:50 /WIND:0 /DIRECTION:0');
 WriteLn('Defauts: V0=800, angle=5, BC=0.35, masse=0.010, diametre=7.62');
 WriteLn('ALT = altitude du terrain; hauteur de lancement = 0.');
 WriteLn('STANDARD/ISA/ICAO: meme approximation tropospherique (0..11000 m).');
 WriteLn('CUSTOM: temperature/pression explicites ou valeurs standard.');
 WriteLn('Cd=0.30/BC: coefficient simplifie, sans tables G1/G7.');
 WriteLn('Vent 0=arriere, 180=face; composante laterale ignoree.');
 WriteLn('Parametres atmospheriques valables pour cet appel seulement.');
 WriteLn('Limites: V0<=3000, distances<=100000, vol<=2000 s.');
 WriteLn;
 WriteLn('Exemple:');
 WriteLn('BALISTIC ENERGY /VELOCITY:800 /MASS:0.010');
 WriteLn('BALISTIC TABLE /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010 /START:0 /END:1000 /STEP:100');
End;

Procedure Atmosphere;
Var
 TK, Saturation, Vapor: Real;
Begin
 If Not HasTemp Then Temp:=15-0.0065*Alt;
 If Not HasPressure Then    Pressure:=1013.25*Exp(5.25588*Ln(1-0.0065*Alt/288.15));
 TK:=Temp+273.15;
 Saturation:=6.1078*Exp(17.2694*Temp/(Temp+237.3));
 Vapor:=Humidity*0.01*Saturation;
 If Vapor>=Pressure Then Fail('Pression de vapeur excessive');
 Rho:=100*(Pressure-Vapor)/(287.05*TK)+100*Vapor/(461.495*TK);
 If Model='VACUUM' Then Rho:=0;
 WindX:=Wind*Cos(Direction*PiValue/180);
 Drag:=0.5*Rho*(0.30/BC)*PiValue*Sqr(Diameter/1000)/4/Mass
End;

Procedure Derivative(Q: State; Var D: State);
Var
 UX, Speed: Real;
Begin
 UX:=Q.vx-WindX;
 Speed:=Sqrt(Sqr(UX)+Sqr(Q.vy));
 D.x:=Q.vx; D.y:=Q.vy;
 D.vx:=-Drag*Speed*UX; D.vy:=-Gravity-Drag*Speed*Q.vy;
 D.t:=1
End;

Procedure Add(Q,D: State; H: Real; Var R: State);
Begin
 R.x:=Q.x+H*D.x; R.y:=Q.y+H*D.y;
 R.vx:=Q.vx+H*D.vx; R.vy:=Q.vy+H*D.vy;
 R.t:=Q.t+H*D.t
End;

Procedure Advance(Var Q: State);
Var
 K1,K2,K3,K4,R: State;
 H,Speed: Real;
Begin
 Speed:=Sqrt(Sqr(Q.vx-WindX)+Sqr(Q.vy));
 H:=0.01;
 If Drag*Speed*H>0.05 Then H:=0.05/(Drag*Speed);
 Derivative(Q,K1); Add(Q,K1,H/2,R); Derivative(R,K2);
 Add(Q,K2,H/2,R); Derivative(R,K3);
 Add(Q,K3,H,R); Derivative(R,K4);
 Q.x:=Q.x+H*(K1.x+2*K2.x+2*K3.x+K4.x)/6;
 Q.y:=Q.y+H*(K1.y+2*K2.y+2*K3.y+K4.y)/6;
 Q.vx:=Q.vx+H*(K1.vx+2*K2.vx+2*K3.vx+K4.vx)/6;
 Q.vy:=Q.vy+H*(K1.vy+2*K2.vy+2*K3.vy+K4.vy)/6;
 Q.t:=Q.t+H
End;

Procedure Mix(L,R: State; F: Real; Var Q: State);
Begin
 Q.x:=L.x+F*(R.x-L.x); Q.y:=L.y+F*(R.y-L.y);
 Q.vx:=L.vx+F*(R.vx-L.vx); Q.vy:=L.vy+F*(R.vy-L.vy);
 Q.t:=L.t+F*(R.t-L.t)
End;

Procedure Init(Var Q: State; Degrees: Real);Begin
 Q.x:=0; Q.y:=0; Q.t:=0;
 Q.vx:=V0*Cos(Degrees*PiValue/180);
 Q.vy:=V0*Sin(Degrees*PiValue/180)
End;

Procedure Flight(Degrees: Real; Var Impact: State; Var MaxY: Real);
Var
 Old: State;
 Count: LongInt;
Begin
 Init(Impact,Degrees); MaxY:=0; Count:=0;
 Repeat
 Old:=Impact; Advance(Impact); Inc(Count);
 If Impact.y>MaxY Then MaxY:=Impact.y;
 If (Impact.t>2000) Or (Count>2000000) Then      Fail('Limite de simulation atteinte');
 Until Impact.y<0;
 Mix(Old,Impact,Old.y/(Old.y-Impact.y),Impact);
 Impact.y:=0
End;

Procedure AtDistance(Var Q,Old: State; X: Real; Var Sample: State);
Var
 Count: LongInt;
Begin
 Count:=0;
 While Q.x<X Do Begin
  Old:=Q; Advance(Q); Inc(Count);
  If (Q.x<=Old.x) Or (Q.t>2000) Or (Count>2000000) Then      Fail('Distance inaccessible')
  ;
 End;
 If Q.x=Old.x Then Sample:=Q
              Else Mix(Old,Q,(X-Old.x)/(Q.x-Old.x),Sample);
 If Sample.y < -0.00001 Then Fail('Distance au-dela de l''impact')
End;

Function Speed(Q: State): Real;Begin
 Speed:=Sqrt(Sqr(Q.vx)+Sqr(Q.vy))
End;

Procedure Row(Q: State; Comma: Boolean);
Var
 V,E: Real;
Begin
 V:=Speed(Q); E:=0.5*Mass*Sqr(V);
 If Fmt='JSON' Then Begin
  If Comma Then WriteLn(',');
  Write('  {"distance_m":',Q.x:0:4,',"time_s":',Q.t:0:6,
  ',"velocity_m_s":',V:0:4,',"energy_J":',E:0:4,
  ',"height_m":',Q.y:0:4,'}')
 End Else If Fmt='CSV' Then    WriteLn(Q.x:0:4,',',Q.t:0:6,',',V:0:4,',',E:0:4,',',
 Q.y:0:4)
  Else
 WriteLn(Q.x:10:2,Q.t:12:4,V:14:2,E:14:2,Q.y:14:2)
End;

Procedure TableOutput;
Var
 X: Real;
 N,J: LongInt;
 Printed: Boolean;
Begin
 Flight(Angle,S,Peak);
 If Cmd='TRAJECTORY' Then Last:=S.x;
 If Last>S.x+0.00001 Then Fail('END au-dela de l''impact');
 If (Last-First)/Step>10000 Then Fail('Table limitee a 10001 lignes');
 Init(TargetState,Angle);
 PreviousState:=TargetState;
 If Fmt='JSON' Then WriteLn('[') Else
 If Fmt='CSV' Then    WriteLn('distance_m,time_s,velocity_m_s,energy_J,height_m')
              Else WriteLn(' DIST. (m)   TEMPS (s) VITESSE (m/s)   ENERGIE (J)   HAUTEUR (m)');
 N:=Trunc((Last-First)/Step); Printed:=False;
 For J:=0 To N Do Begin
  X:=First+J*Step;
  AtDistance(TargetState,PreviousState,X,SampleState);
  Row(SampleState,Printed); Printed:=True
 End;
 If (Cmd='TRAJECTORY') And (Last-SampleState.x>0.00001) Then    Row(S,Printed);
 If Fmt='JSON' Then WriteLn(#10,']')
End;

BEGIN
 V0:=800; Angle:=5; BC:=0.35; Mass:=0.010; Diameter:=7.62;
 Alt:=0; Step:=100; Dist:=500; First:=0; Last:=1000;
 Temp:=15; Pressure:=1013.25; Humidity:=0; Wind:=0; Direction:=0;
 Model:='STANDARD'; Fmt:='TEXT'; Optimize:=False;
 HasSpeed:=False; HasV0:=False; HasDist:=False;
 HasTemp:=False; HasPressure:=False;
 If ParamCount=0 Then Begin
  Help; Halt(0)
 End;
 Cmd:=Upper(ParamStr(1));
 If (Cmd='/HELP') Or (Cmd='/?') Or (Cmd='HELP') Then Begin
  Help; Halt(0)
 End;
 If (Cmd<>'TRAJECTORY') And (Cmd<>'VELOCITY') And (Cmd<>'ENERGY') And
 (Cmd<>'RANGE') And (Cmd<>'TABLE') And (Cmd<>'ATMOSPHERE') Then    Fail(
 'Sous-commande inconnue: '+Cmd);
 For I:=2 To ParamCount Do Begin
  Arg:=ParamStr(I);
  If Upper(Arg)='/OPTIMIZE' Then Begin
   If Cmd<>'RANGE' Then Fail('OPTIMIZE exige RANGE');
   Optimize:=True
  End Else
  Begin
   P:=Pos(':',Arg);
   If (P<3) Or (Arg[1]<>'/') Then Fail('Option invalide: '+Arg);
   Key:=Upper(Copy(Arg,2,P-2)); Value:=Copy(Arg,P+1,255);
   If ((Key='START') Or (Key='END')) And (Cmd<>'TABLE') Then        Fail(
   'START/END exigent TABLE');
   If (Key='STEP') And (Cmd<>'TABLE') And (Cmd<>'TRAJECTORY') Then        Fail(
   'STEP exige TABLE ou TRAJECTORY');
   If (Key='DIST') And (Cmd<>'VELOCITY') And (Cmd<>'ENERGY') Then        Fail(
   'DIST exige VELOCITY ou ENERGY');
   If (Key='MODEL') And (Cmd<>'ATMOSPHERE') Then        Fail(
   'MODEL exige ATMOSPHERE; utiliser ATM pour le vol');
   If (Cmd='ATMOSPHERE') And ((Key='V0') Or (Key='ANGLE') Or
   (Key='BC') Or (Key='MASS') Or (Key='DIAMETER')) Then        Fail(
   'Option de projectile incompatible avec ATMOSPHERE');
   If (Key='ATM') Or (Key='MODEL') Then Model:=Upper(Value) Else
   If Key='FORMAT' Then Begin
    If (Cmd<>'TABLE') And (Cmd<>'TRAJECTORY') Then          Fail(
    'FORMAT exige TABLE ou TRAJECTORY');
    Fmt:=Upper(Value)
   End
   Else If Key='V0' Then Begin
    V0:=Number(Value); HasV0:=True
   End
   Else If Key='ANGLE' Then Angle:=Number(Value) Else
   If Key='BC' Then BC:=Number(Value) Else
   If Key='MASS' Then Mass:=Number(Value) Else
   If Key='DIAMETER' Then Diameter:=Number(Value) Else
   If Key='ALT' Then Alt:=Number(Value) Else
   If Key='STEP' Then Step:=Number(Value) Else
   If Key='DIST' Then Begin
    Dist:=Number(Value); HasDist:=True
   End
   Else If Key='START' Then First:=Number(Value) Else
   If Key='END' Then Last:=Number(Value) Else
   If Key='TEMP' Then Begin
    Temp:=Number(Value); HasTemp:=True
   End
   Else If Key='PRESSURE' Then Begin
    Pressure:=Number(Value); HasPressure:=True
   End
   Else If Key='HUMIDITY' Then Humidity:=Number(Value) Else
   If Key='WIND' Then Wind:=Number(Value) Else
   If Key='DIRECTION' Then Direction:=Number(Value) Else
   If Key='VELOCITY' Then Begin
    If Cmd<>'ENERGY' Then Fail('VELOCITY exige ENERGY');
    DirectSpeed:=Number(Value); HasSpeed:=True
   End Else Fail('Option inconnue: '+Key)
  End
 End;
 If (V0<=0) Or (V0>3000) Then Fail('V0 doit etre dans ]0,3000]');
 If (Angle<0) Or (Angle>=90) Then Fail('ANGLE doit etre dans [0,90[');
 If (BC<0.01) Or (BC>10) Then Fail('BC doit etre dans [0.01,10]');
 If (Mass<0.000001) Or (Mass>1000) Then Fail('MASS doit etre dans [0.000001,1000] kg');
 If (Diameter<=0) Or (Diameter>1000) Then Fail('DIAMETER doit etre dans ]0,1000] mm');
 If (Alt<0) Or (Alt>11000) Then Fail('ALT doit etre dans [0,11000]');
 If (Step<=0) Or (Step>100000) Then Fail('STEP doit etre dans ]0,100000]');
 If (Dist<0) Or (Dist>100000) Or (First<0) Or (Last<First) Or
 (Last>100000) Then Fail('Distances invalides (0..100000 m)');
 If (Temp< -100) Or (Temp>60) Then Fail('TEMP doit etre dans [-100,60]');
 If (Pressure<=0) Or (Pressure>1100) Then Fail('PRESSURE doit etre dans ]0,1100]');
 If (Humidity<0) Or (Humidity>100) Then Fail('HUMIDITY doit etre dans [0,100]');
 If (Wind<0) Or (Wind>150) Or (Direction<0) Or (Direction>360) Then    Fail(
 'Vent invalide: vitesse 0..150, direction 0..360');
 If (Fmt<>'TEXT') And (Fmt<>'CSV') And (Fmt<>'JSON') Then Fail('FORMAT inconnu');
 If (Model<>'STANDARD') And (Model<>'ISA') And (Model<>'ICAO') And
 (Model<>'CUSTOM') And (Model<>'VACUUM') Then Fail('Modele inconnu');
 If ((HasTemp Or HasPressure) Or (Humidity<>0)) And
 (Model<>'CUSTOM') Then Fail('TEMP/PRESSURE/HUMIDITY exigent CUSTOM');
 If HasSpeed And (HasV0 Or HasDist) Then Fail('VELOCITY incompatible avec V0/DIST');
 If HasSpeed And ((DirectSpeed<0) Or (DirectSpeed>3000)) Then    Fail(
 'VELOCITY doit etre dans [0,3000]');
 Atmosphere;
 If Cmd='ATMOSPHERE' Then Begin
  WriteLn('Modele       : ',Model);
  WriteLn('Altitude     : ',Alt:0:2,' m');
  WriteLn('Temperature  : ',Temp:0:2,' C');
  WriteLn('Pression     : ',Pressure:0:2,' hPa');
  WriteLn('Humidite     : ',Humidity:0:2,' %');
  WriteLn('Densite      : ',Rho:0:6,' kg/m3');
  WriteLn('Vent         : ',Wind:0:2,' m/s, ',Direction:0:2,' deg');
  Halt(0)
 End;
 If (Cmd='TABLE') Or (Cmd='TRAJECTORY') Then TableOutput Else
 If Cmd='RANGE' Then Begin
  If Optimize Then Begin
   BestRange:=-1; BestAngle:=0;
   For I:=1 To 899 Do Begin
    A:=I/10; Flight(A,S,Peak);
    If S.x>BestRange Then Begin
     BestRange:=S.x; BestAngle:=A
    End
   End;
   Angle:=BestAngle
  End;
  Flight(Angle,S,Peak);
  WriteLn('Vitesse initiale : ',V0:0:2,' m/s');
  WriteLn('Angle de tir     : ',Angle:0:2,' deg');
  WriteLn('Portee           : ',S.x:0:2,' m');
  WriteLn('Temps de vol     : ',S.t:0:4,' s');
  WriteLn('Hauteur maximale : ',Peak:0:2,' m')
 End Else
 Begin
  If Not HasSpeed Then Begin
   Flight(Angle,S,Peak);
   If Dist>S.x+0.00001 Then Fail('DIST au-dela de l''impact');
   Init(TargetState,Angle); PreviousState:=TargetState;
   AtDistance(TargetState,PreviousState,Dist,SampleState);
   DirectSpeed:=Speed(SampleState)
  End;
  If Cmd='VELOCITY' Then Begin
   WriteLn('Vitesse initiale : ',V0:0:2,' m/s');
   WriteLn('Distance         : ',Dist:0:2,' m')
  End Else WriteLn('Masse            : ',Mass:0:6,' kg');
  WriteLn('Vitesse          : ',DirectSpeed:0:2,' m/s');
  If Cmd='ENERGY' Then      WriteLn('Energie          : ',0.5*Mass*Sqr(DirectSpeed):0:2,
  ' J')
 End
END.
