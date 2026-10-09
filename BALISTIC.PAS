{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/ballistics-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

program Balistic;
{ Turbo Pascal 7 / Free Pascal (-Mtp). SI units except diameter (mm),
  temperature (C), pressure (hPa), humidity (%), angles (degrees).
  Educational point-mass model: Cd = 0.30 / BC, NOT a G1/G7 drag table.
  ALT is elevation above sea level; launch and impact are at local y=0.
  Wind direction: 0 = tailwind, 180 = headwind; transverse component
  is ignored by this two-dimensional model. No persistent settings. }
const
  Gravity = 9.80665;
  PiValue = 3.141592653589793;
type
  State = record x,y,vx,vy,t: Real end;
var
  Cmd, Model, Fmt, Arg, Key, Value: string;
  V0, Angle, BC, Mass, Diameter, Alt, Step, Dist, First, Last: Real;
  Temp, Pressure, Humidity, Wind, Direction, Rho, WindX, Drag: Real;
  DirectSpeed: Real;
  Optimize, HasSpeed, HasV0, HasDist, HasTemp, HasPressure: Boolean;
  S, TargetState, PreviousState, SampleState: State;
  Peak, BestRange, BestAngle, A: Real;
  I, P: Integer;

procedure Fail(Msg: string);
begin
  WriteLn('Erreur: ',Msg);
  Halt(1)
end;

function Upper(S: string): string;
var J: Integer;
begin
  for J:=1 to Length(S) do S[J]:=UpCase(S[J]);
  Upper:=S
end;

function Number(S: string): Real;
var N: Real; E: Integer; J: Integer;
begin
  if Length(S)=0 then Fail('Valeur numerique manquante');
  for J:=1 to Length(S) do
    if not (S[J] in ['0'..'9','+','-','.','e','E']) then
      Fail('Nombre invalide: '+S);
  Val(S,N,E);
  if E<>0 then Fail('Nombre invalide: '+S);
  if Abs(N)>1.0E8 then Fail('Nombre hors limites');
  Number:=N
end;

procedure Help;
begin
  WriteLn('BALISTIC - Cette commande permet de simuler un moteur balistique simplifi'+#130+'.');
  WriteLn;
  WriteLn('Syntaxe: BALISTIC TRAJECTORY|VELOCITY|ENERGY|RANGE|TABLE|ATMOSPHERE');
  WriteLn;
  WriteLn('Unites: m, m/s, kg, mm (diametre), degres, secondes, joules.');
  WriteLn('Options de vol: /V0:800 /ANGLE:5 /BC:0.35 /MASS:0.010');
  WriteLn(' /DIAMETER:7.62 /ALT:0 /ATM:STANDARD');
  WriteLn('TRAJECTORY: /STEP:100 (jusqu''a impact)');
  WriteLn('VELOCITY: /DIST:500');
  WriteLn('ENERGY: /VELOCITY:800 /MASS:0.010 ou options de vol /DIST:500');
  WriteLn('RANGE: /ANGLE:45 ou /OPTIMIZE (precision 0.1 degre)');
  WriteLn('TABLE: /START:0 /END:1000 /STEP:100 /FORMAT:TEXT|CSV|JSON');
  WriteLn('Atmosphere commune: /ATM:STANDARD|ISA|ICAO|CUSTOM|VACUUM');
  WriteLn('ATMOSPHERE: /MODEL:STANDARD /ALT:1000 /TEMP:15');
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
  WriteLn('Exemple: BALISTIC ENERGY /VELOCITY:800 /MASS:0.010')
end;

procedure Atmosphere;
var TK, Saturation, Vapor: Real;
begin
  if not HasTemp then Temp:=15-0.0065*Alt;
  if not HasPressure then
    Pressure:=1013.25*Exp(5.25588*Ln(1-0.0065*Alt/288.15));
  TK:=Temp+273.15;
  Saturation:=6.1078*Exp(17.2694*Temp/(Temp+237.3));
  Vapor:=Humidity*0.01*Saturation;
  if Vapor>=Pressure then Fail('Pression de vapeur excessive');
  Rho:=100*(Pressure-Vapor)/(287.05*TK)+100*Vapor/(461.495*TK);
  if Model='VACUUM' then Rho:=0;
  WindX:=Wind*Cos(Direction*PiValue/180);
  Drag:=0.5*Rho*(0.30/BC)*PiValue*Sqr(Diameter/1000)/4/Mass
end;

procedure Derivative(Q: State; var D: State);
var UX, Speed: Real;
begin
  UX:=Q.vx-WindX;
  Speed:=Sqrt(Sqr(UX)+Sqr(Q.vy));
  D.x:=Q.vx; D.y:=Q.vy;
  D.vx:=-Drag*Speed*UX; D.vy:=-Gravity-Drag*Speed*Q.vy;
  D.t:=1
end;

function Add(Q,D: State; H: Real): State;
var R: State;
begin
  R.x:=Q.x+H*D.x; R.y:=Q.y+H*D.y;
  R.vx:=Q.vx+H*D.vx; R.vy:=Q.vy+H*D.vy;
  R.t:=Q.t+H*D.t; Add:=R
end;

procedure Advance(var Q: State);
var K1,K2,K3,K4,R: State; H,Speed: Real;
begin
  Speed:=Sqrt(Sqr(Q.vx-WindX)+Sqr(Q.vy));
  H:=0.01;
  if Drag*Speed*H>0.05 then H:=0.05/(Drag*Speed);
  Derivative(Q,K1); R:=Add(Q,K1,H/2); Derivative(R,K2);
  R:=Add(Q,K2,H/2); Derivative(R,K3);
  R:=Add(Q,K3,H); Derivative(R,K4);
  Q.x:=Q.x+H*(K1.x+2*K2.x+2*K3.x+K4.x)/6;
  Q.y:=Q.y+H*(K1.y+2*K2.y+2*K3.y+K4.y)/6;
  Q.vx:=Q.vx+H*(K1.vx+2*K2.vx+2*K3.vx+K4.vx)/6;
  Q.vy:=Q.vy+H*(K1.vy+2*K2.vy+2*K3.vy+K4.vy)/6;
  Q.t:=Q.t+H
end;

function Mix(L,R: State; F: Real): State;
var Q: State;
begin
  Q.x:=L.x+F*(R.x-L.x); Q.y:=L.y+F*(R.y-L.y);
  Q.vx:=L.vx+F*(R.vx-L.vx); Q.vy:=L.vy+F*(R.vy-L.vy);
  Q.t:=L.t+F*(R.t-L.t); Mix:=Q
end;

procedure Init(var Q: State; Degrees: Real);
begin
  Q.x:=0; Q.y:=0; Q.t:=0;
  Q.vx:=V0*Cos(Degrees*PiValue/180);
  Q.vy:=V0*Sin(Degrees*PiValue/180)
end;

procedure Flight(Degrees: Real; var Impact: State; var MaxY: Real);
var Old: State; Count: LongInt;
begin
  Init(Impact,Degrees); MaxY:=0; Count:=0;
  repeat
    Old:=Impact; Advance(Impact); Inc(Count);
    if Impact.y>MaxY then MaxY:=Impact.y;
    if (Impact.t>2000) or (Count>2000000) then
      Fail('Limite de simulation atteinte');
  until Impact.y<0;
  Impact:=Mix(Old,Impact,Old.y/(Old.y-Impact.y));
  Impact.y:=0
end;

procedure AtDistance(var Q,Old: State; X: Real; var Sample: State);
var Count: LongInt;
begin
  Count:=0;
  while Q.x<X do begin
    Old:=Q; Advance(Q); Inc(Count);
    if (Q.x<=Old.x) or (Q.t>2000) or (Count>2000000) then
      Fail('Distance inaccessible');
  end;
  if Q.x=Old.x then Sample:=Q
  else Sample:=Mix(Old,Q,(X-Old.x)/(Q.x-Old.x));
  if Sample.y < -0.00001 then Fail('Distance au-dela de l''impact')
end;

function Speed(Q: State): Real;
begin Speed:=Sqrt(Sqr(Q.vx)+Sqr(Q.vy)) end;

procedure Row(Q: State; Comma: Boolean);
var V,E: Real;
begin
  V:=Speed(Q); E:=0.5*Mass*Sqr(V);
  if Fmt='JSON' then begin
    if Comma then WriteLn(',');
    Write('  {"distance_m":',Q.x:0:4,',"time_s":',Q.t:0:6,
      ',"velocity_m_s":',V:0:4,',"energy_J":',E:0:4,
      ',"height_m":',Q.y:0:4,'}')
  end else if Fmt='CSV' then
    WriteLn(Q.x:0:4,',',Q.t:0:6,',',V:0:4,',',E:0:4,',',Q.y:0:4)
  else
    WriteLn(Q.x:10:2,Q.t:12:4,V:14:2,E:14:2,Q.y:14:2)
end;

procedure TableOutput;
var X: Real; N,J: LongInt; Printed: Boolean;
begin
  Flight(Angle,S,Peak);
  if Cmd='TRAJECTORY' then Last:=S.x;
  if Last>S.x+0.00001 then Fail('END au-dela de l''impact');
  if (Last-First)/Step>10000 then Fail('Table limitee a 10001 lignes');
  Init(TargetState,Angle);
  PreviousState:=TargetState;
  if Fmt='JSON' then WriteLn('[')
  else if Fmt='CSV' then
    WriteLn('distance_m,time_s,velocity_m_s,energy_J,height_m')
  else WriteLn(' DIST. (m)   TEMPS (s) VITESSE (m/s)   ENERGIE (J)   HAUTEUR (m)');
  N:=Trunc((Last-First)/Step); Printed:=False;
  for J:=0 to N do begin
    X:=First+J*Step;
    AtDistance(TargetState,PreviousState,X,SampleState);
    Row(SampleState,Printed); Printed:=True
  end;
  if (Cmd='TRAJECTORY') and (Last-SampleState.x>0.00001) then
    Row(S,Printed);
  if Fmt='JSON' then WriteLn(#10,']')
end;

begin
  V0:=800; Angle:=5; BC:=0.35; Mass:=0.010; Diameter:=7.62;
  Alt:=0; Step:=100; Dist:=500; First:=0; Last:=1000;
  Temp:=15; Pressure:=1013.25; Humidity:=0; Wind:=0; Direction:=0;
  Model:='STANDARD'; Fmt:='TEXT'; Optimize:=False;
  HasSpeed:=False; HasV0:=False; HasDist:=False;
  HasTemp:=False; HasPressure:=False;
  if ParamCount=0 then begin Help; Halt(0) end;
  Cmd:=Upper(ParamStr(1));
  if (Cmd='/HELP') or (Cmd='/?') or (Cmd='HELP') then begin Help; Halt(0) end;
  if (Cmd<>'TRAJECTORY') and (Cmd<>'VELOCITY') and (Cmd<>'ENERGY') and
     (Cmd<>'RANGE') and (Cmd<>'TABLE') and (Cmd<>'ATMOSPHERE') then
    Fail('Sous-commande inconnue: '+Cmd);
  for I:=2 to ParamCount do begin
    Arg:=ParamStr(I);
    if Upper(Arg)='/OPTIMIZE' then begin
      if Cmd<>'RANGE' then Fail('OPTIMIZE exige RANGE');
      Optimize:=True
    end else begin
      P:=Pos(':',Arg);
      if (P<3) or (Arg[1]<>'/') then Fail('Option invalide: '+Arg);
      Key:=Upper(Copy(Arg,2,P-2)); Value:=Copy(Arg,P+1,255);
      if ((Key='START') or (Key='END')) and (Cmd<>'TABLE') then
        Fail('START/END exigent TABLE');
      if (Key='STEP') and (Cmd<>'TABLE') and (Cmd<>'TRAJECTORY') then
        Fail('STEP exige TABLE ou TRAJECTORY');
      if (Key='DIST') and (Cmd<>'VELOCITY') and (Cmd<>'ENERGY') then
        Fail('DIST exige VELOCITY ou ENERGY');
      if (Key='MODEL') and (Cmd<>'ATMOSPHERE') then
        Fail('MODEL exige ATMOSPHERE; utiliser ATM pour le vol');
      if (Cmd='ATMOSPHERE') and ((Key='V0') or (Key='ANGLE') or
        (Key='BC') or (Key='MASS') or (Key='DIAMETER')) then
        Fail('Option de projectile incompatible avec ATMOSPHERE');
      if (Key='ATM') or (Key='MODEL') then Model:=Upper(Value)
      else if Key='FORMAT' then begin
        if (Cmd<>'TABLE') and (Cmd<>'TRAJECTORY') then
          Fail('FORMAT exige TABLE ou TRAJECTORY');
        Fmt:=Upper(Value)
      end
      else if Key='V0' then begin V0:=Number(Value); HasV0:=True end
      else if Key='ANGLE' then Angle:=Number(Value)
      else if Key='BC' then BC:=Number(Value)
      else if Key='MASS' then Mass:=Number(Value)
      else if Key='DIAMETER' then Diameter:=Number(Value)
      else if Key='ALT' then Alt:=Number(Value)
      else if Key='STEP' then Step:=Number(Value)
      else if Key='DIST' then begin Dist:=Number(Value); HasDist:=True end
      else if Key='START' then First:=Number(Value)
      else if Key='END' then Last:=Number(Value)
      else if Key='TEMP' then begin Temp:=Number(Value); HasTemp:=True end
      else if Key='PRESSURE' then begin Pressure:=Number(Value); HasPressure:=True end
      else if Key='HUMIDITY' then Humidity:=Number(Value)
      else if Key='WIND' then Wind:=Number(Value)
      else if Key='DIRECTION' then Direction:=Number(Value)
      else if Key='VELOCITY' then begin
        if Cmd<>'ENERGY' then Fail('VELOCITY exige ENERGY');
        DirectSpeed:=Number(Value); HasSpeed:=True
      end else Fail('Option inconnue: '+Key)
    end
  end;
  if (V0<=0) or (V0>3000) then Fail('V0 doit etre dans ]0,3000]');
  if (Angle<0) or (Angle>=90) then Fail('ANGLE doit etre dans [0,90[');
  if (BC<0.01) or (BC>10) then Fail('BC doit etre dans [0.01,10]');
  if (Mass<0.000001) or (Mass>1000) then Fail('MASS doit etre dans [0.000001,1000] kg');
  if (Diameter<=0) or (Diameter>1000) then Fail('DIAMETER doit etre dans ]0,1000] mm');
  if (Alt<0) or (Alt>11000) then Fail('ALT doit etre dans [0,11000]');
  if (Step<=0) or (Step>100000) then Fail('STEP doit etre dans ]0,100000]');
  if (Dist<0) or (Dist>100000) or (First<0) or (Last<First) or
     (Last>100000) then Fail('Distances invalides (0..100000 m)');
  if (Temp< -100) or (Temp>60) then Fail('TEMP doit etre dans [-100,60]');
  if (Pressure<=0) or (Pressure>1100) then Fail('PRESSURE doit etre dans ]0,1100]');
  if (Humidity<0) or (Humidity>100) then Fail('HUMIDITY doit etre dans [0,100]');
  if (Wind<0) or (Wind>150) or (Direction<0) or (Direction>360) then
    Fail('Vent invalide: vitesse 0..150, direction 0..360');
  if (Fmt<>'TEXT') and (Fmt<>'CSV') and (Fmt<>'JSON') then Fail('FORMAT inconnu');
  if (Model<>'STANDARD') and (Model<>'ISA') and (Model<>'ICAO') and
     (Model<>'CUSTOM') and (Model<>'VACUUM') then Fail('Modele inconnu');
  if ((HasTemp or HasPressure) or (Humidity<>0)) and
     (Model<>'CUSTOM') then Fail('TEMP/PRESSURE/HUMIDITY exigent CUSTOM');
  if HasSpeed and (HasV0 or HasDist) then Fail('VELOCITY incompatible avec V0/DIST');
  if HasSpeed and ((DirectSpeed<0) or (DirectSpeed>3000)) then
    Fail('VELOCITY doit etre dans [0,3000]');
  Atmosphere;
  if Cmd='ATMOSPHERE' then begin
    WriteLn('Modele       : ',Model);
    WriteLn('Altitude     : ',Alt:0:2,' m');
    WriteLn('Temperature  : ',Temp:0:2,' C');
    WriteLn('Pression     : ',Pressure:0:2,' hPa');
    WriteLn('Humidite     : ',Humidity:0:2,' %');
    WriteLn('Densite      : ',Rho:0:6,' kg/m3');
    WriteLn('Vent         : ',Wind:0:2,' m/s, ',Direction:0:2,' deg');
    Halt(0)
  end;
  if (Cmd='TABLE') or (Cmd='TRAJECTORY') then TableOutput
  else if Cmd='RANGE' then begin
    if Optimize then begin
      BestRange:=-1; BestAngle:=0;
      for I:=1 to 899 do begin
        A:=I/10; Flight(A,S,Peak);
        if S.x>BestRange then begin BestRange:=S.x; BestAngle:=A end
      end;
      Angle:=BestAngle
    end;
    Flight(Angle,S,Peak);
    WriteLn('Vitesse initiale : ',V0:0:2,' m/s');
    WriteLn('Angle de tir     : ',Angle:0:2,' deg');
    WriteLn('Portee           : ',S.x:0:2,' m');
    WriteLn('Temps de vol     : ',S.t:0:4,' s');
    WriteLn('Hauteur maximale : ',Peak:0:2,' m')
  end else begin
    if not HasSpeed then begin
      Flight(Angle,S,Peak);
      if Dist>S.x+0.00001 then Fail('DIST au-dela de l''impact');
      Init(TargetState,Angle); PreviousState:=TargetState;
      AtDistance(TargetState,PreviousState,Dist,SampleState);
      DirectSpeed:=Speed(SampleState)
    end;
    if Cmd='VELOCITY' then begin
      WriteLn('Vitesse initiale : ',V0:0:2,' m/s');
      WriteLn('Distance         : ',Dist:0:2,' m')
    end else WriteLn('Masse            : ',Mass:0:6,' kg');
    WriteLn('Vitesse          : ',DirectSpeed:0:2,' m/s');
    if Cmd='ENERGY' then
      WriteLn('Energie          : ',0.5*Mass*Sqr(DirectSpeed):0:2,' J')
  end
end.
