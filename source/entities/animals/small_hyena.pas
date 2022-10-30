(* Weak predator, attacks other animals *)

unit small_hyena;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, universe, combat_resolver;

(* Create a hyena *)
procedure createSmallHyena(uniqueid, npcx, npcy: smallint);
(* Take a turn *)
procedure takeTurn(id: smallint);
(* Creature death *)
procedure death;
(* Decision tree for Neutral state *)
procedure decisionNeutral(id: smallint);
(* Decision tree for Hostile state *)
procedure decisionHostile(id: smallint);
(* Move in a random direction *)
procedure wander(id, spx, spy: smallint);
(* Chase the player *)
procedure chasePlayer(id, spx, spy: smallint);
(* Check if player is next to NPC *)
function isNextToPlayer(spx, spy: smallint): boolean;
(* Run from player *)
procedure escapePlayer(id, spx, spy: smallint);
(* NPC attacks another entity *)
procedure combat(npcID, enemyID: smallint);

implementation

uses
  entities, globalutils, ui, los, map;

procedure createSmallHyena(uniqueid, npcx, npcy: smallint);
var
  mood: byte;
begin
  (* Detemine hostility *)
  mood := randomRange(1, 3);
  (* Add a hyena to the list of creatures *)
  entities.listLength := length(entities.entityList);
  SetLength(entities.entityList, entities.listLength + 1);
  with entities.entityList[entities.listLength] do
  begin
    npcID := uniqueid;
    race := 'Small Hyena';
    intName := 'smallHyena';
    article := True;
    description := 'a skinny cave hyena';
    glyph := 'h';
    glyphColour := 'yellow';
    maxHP := randomRange(3, 5) + universe.currentDepth;
    currentHP := maxHP;
    attack := randomRange(entityList[0].attack - 2, entityList[0].attack + 1);
    defence := randomRange(entityList[0].defence - 2, entityList[0].defence + 1);
    weaponDice := 0;
    weaponAdds := 0;
    xpReward := maxHP;
    visionRange := 4;
    moveCount := 0;
    targetX := 0;
    targetY := 0;
    inView := False;
    blocks := False;
    faction := animalFaction;
    if (mood = 1) then
      state := stateHostile
    else
      state := stateNeutral;
    discovered := False;
    weaponEquipped := False;
    armourEquipped := False;
    isDead := False;
    stsDrunk := False;
    stsPoison := False;
    stsBewild := False;
    tmrDrunk := 0;
    tmrPoison := 0;
    tmrBewild := 0;
    hasPath := False;
    destinationReached := False;
    entities.initPath(uniqueid);
    posX := npcx;
    posY := npcy;
    entities.initPath(uniqueid);
  end;
  (* Occupy tile *)
  map.occupy(npcx, npcy);
end;


procedure takeTurn(id: smallint);
begin
  (* Check for status effects *)

  { Poison }
  if (entityList[id].stsPoison = True) then
  begin
    Dec(entityList[id].currentHP);
    Dec(entityList[id].tmrPoison);
    if (entityList[id].inView = True) and (entityList[0].moveCount div 2 = 0) then
      ui.displayMessage(entityList[id].race + ' looks sick');
    if (entityList[id].tmrPoison <= 0) then
      entityList[id].stsBewild := False;
  end;
  { Bewildered }
  if (entityList[id].stsBewild = True) then
  begin
    Dec(entityList[id].tmrBewild);
    if (entityList[id].inView = True) and (entityList[0].moveCount div 2 = 0) then
      ui.displayMessage(entityList[id].race + ' looks bewildered')
    else if (entityList[id].inView = True) then
    begin
      ui.displayMessage(entityList[id].race + ' bites itself');
      Dec(entityList[id].currentHP);
    end;
    wander(id, entityList[id].posX, entityList[id].posY);
    if (entityList[id].tmrBewild <= 0) then
      entityList[id].stsBewild := False;
  end;

  if (entityList[id].stsBewild <> True) then
  begin
    case entityList[id].state of
      stateNeutral: decisionNeutral(id);
      stateHostile: decisionHostile(id);
      else
        decisionNeutral(id);
    end;
  end;
end;

procedure death;
begin
  Inc(deathList[9]);
end;

procedure decisionNeutral(id: smallint);
var
  stopAndSmellFlowers: byte;
begin
  stopAndSmellFlowers := globalutils.randomRange(1, 3);
  if (stopAndSmellFlowers = 1) then
    { Either wander randomly }
    wander(id, entityList[id].posX, entityList[id].posY)
  else
    { or stay in place }
    entities.moveNPC(id, entityList[id].posX, entityList[id].posY);
end;

procedure decisionHostile(id: smallint);
var
  stopAndSmellFlowers: byte;
begin
  { Randomly decide whether to wander or attack }
  stopAndSmellFlowers := globalutils.randomRange(1, 2);
  if (stopAndSmellFlowers = 1) then
    wander(id, entityList[id].posX, entityList[id].posY)

  { If NPC can see the player }
  else if (los.inView(entityList[id].posX, entityList[id].posY,
    entityList[0].posX, entityList[0].posY, entityList[id].visionRange) = True) then
  begin
    entityList[id].moveCount := 5;
    { If next to the player }
    if (isNextToPlayer(entityList[id].posX, entityList[id].posY) = True) then
      { Attack the Player }
      combat(id, 0)
    else
      { Chase the player }
      chasePlayer(id, entityList[id].posX, entityList[id].posY);
  end
  { If player not in sight }
  else
    wander(id, entityList[id].posX, entityList[id].posY);
end;


procedure wander(id, spx, spy: smallint);
var
  direction, attempts, testx, testy: smallint;
begin
  attempts := 0;
  testx := 0;
  testy := 0;
  direction := 0;
  repeat
    (* Reset values after each failed loop so they don't keep dec/incrementing *)
    testx := spx;
    testy := spy;
    direction := random(6);
    (* limit the number of attempts to move so the game doesn't hang if NPC is stuck *)
    Inc(attempts);
    if attempts > 10 then
    begin
      entities.moveNPC(id, spx, spy);
      exit;
    end;
    case direction of
      0: Dec(testy);
      1: Inc(testy);
      2: Dec(testx);
      3: Inc(testx);
      4: testx := spx;
      5: testy := spy;
    end
  until (map.canMove(testx, testy) = True) and (map.isOccupied(testx, testy) = False);
  entities.moveNPC(id, testx, testy);
end;

procedure chasePlayer(id, spx, spy: smallint);
var
  newX, newY, dx, dy: smallint;
  distance: double;
begin
  newX := 0;
  newY := 0;
  (* Get new coordinates to chase the player *)
  dx := entityList[0].posX - spx;
  dy := entityList[0].posY - spy;
  if (dx = 0) and (dy = 0) then
  begin
    newX := spx;
    newy := spy;
  end
  else
  begin
    distance := sqrt(dx ** 2 + dy ** 2);
    dx := round(dx / distance);
    dy := round(dy / distance);
    newX := spx + dx;
    newY := spy + dy;
  end;
  (* New coordinates set. Check if they are walkable *)
  if (map.canMove(newX, newY) = True) then
  begin
    (* Do they contain the player *)
    if (map.hasPlayer(newX, newY) = True) then
    begin
      (* Remain on original tile and attack *)
      entities.moveNPC(id, spx, spy);
      combat(id, 0);
    end
    (* Else if tile does not contain player, check for another entity *)
    else if (map.isOccupied(newX, newY) = True) then
    begin
      combat(id, getCreatureID(newX, newY));
      entities.moveNPC(id, spx, spy);
    end
    (* if map is unoccupied, move to that tile *)
    else if (map.isOccupied(newX, newY) = False) then
      entities.moveNPC(id, newX, newY);
  end
  else
    wander(id, spx, spy);
end;

function isNextToPlayer(spx, spy: smallint): boolean;
begin
  Result := False;
  if (map.hasPlayer(spx, spy - 1) = True) then { NORTH }
    Result := True;
  if (map.hasPlayer(spx + 1, spy - 1) = True) then { NORTH EAST }
    Result := True;
  if (map.hasPlayer(spx + 1, spy) = True) then { EAST }
    Result := True;
  if (map.hasPlayer(spx + 1, spy + 1) = True) then { SOUTH EAST }
    Result := True;
  if (map.hasPlayer(spx, spy + 1) = True) then { SOUTH }
    Result := True;
  if (map.hasPlayer(spx - 1, spy + 1) = True) then { SOUTH WEST }
    Result := True;
  if (map.hasPlayer(spx - 1, spy) = True) then { WEST }
    Result := True;
  if (map.hasPlayer(spx - 1, spy - 1) = True) then { NORTH WEST }
    Result := True;
end;

procedure escapePlayer(id, spx, spy: smallint);
var
  newX, newY, dx, dy: smallint;
  distance: single;
begin
  newX := 0;
  newY := 0;
  (* Get new coordinates to escape the player *)
  dx := entityList[0].posX - spx;
  dy := entityList[0].posY - spy;
  if (dx = 0) and (dy = 0) then
  begin
    newX := spx;
    newy := spy;
  end
  else
  begin
    distance := sqrt(dx ** 2 + dy ** 2);
    dx := round(dx / distance);
    dy := round(dy / distance);
    if (dx > 0) then
      dx := -1;
    if (dx < 0) then
      dx := 1;
    dy := round(dy / distance);
    if (dy > 0) then
      dy := -1;
    if (dy < 0) then
      dy := 1;
    newX := spx + dx;
    newY := spy + dy;
  end;
  if (map.canMove(newX, newY) = True) then
  begin
    if (map.hasPlayer(newX, newY) = True) then
    begin
      entities.moveNPC(id, spx, spy);
      combat(id, 0);
    end
    else if (map.isOccupied(newX, newY) = False) then
      entities.moveNPC(id, newX, newY);
  end
  else
    wander(id, spx, spy);
end;

procedure combat(npcID, enemyID: smallint);
var
  damageAmount: smallint;
begin
  damageAmount := globalutils.randomRange(1, entityList[npcID].attack) -
    entityList[enemyID].defence;
  (* If damage is done *)
  if (damageAmount > 0) then
  begin
    entityList[enemyID].currentHP := (entityList[enemyID].currentHP - damageAmount);
    (* If the enemy is killed *)
    if (entityList[enemyID].currentHP < 1) then
    begin
      if (enemyID = 0) then
        (* If the enemy is the player *)
      begin
        killer := 'a ' + entityList[npcID].race;
        exit;
      end
      else
        (* If the enemy is an NPC *)
        killEntity(enemyID);
    end
    else
    begin
      if (damageAmount = 1) then
      begin
        if (enemyID = 0) then
          (* If the player is slightly wounded *)
          ui.displayMessage('The hyena slightly wounds you')
        else
          (* If an NPC is slightly wounded *)
          ui.displayMessage('The hyena slightly wounds the ' + entityList[enemyID].race);
      end
      else
        (* If significant damage is done *)
      begin
        if (enemyID = 0) then
          (* To the player *)
        begin
          ui.displayMessage('The hyena bites you, inflicting ' +
            IntToStr(damageAmount) + ' damage');
          (* Update health display to show damage *)
          ui.updateHealth;
        end
        else
          (* To an NPC *)
          ui.displayMessage('The hyena bites the ' + entityList[enemyID].race);
      end;
    end;
  end
  else
    (* If no damage is done *)
  begin
    if (enemyID = 0) then
    begin
      ui.displayMessage('The hyena strikes but misses');
      combat_resolver.spiteDMG(npcID);
    end
    else
      ui.displayMessage('The hyena nips at the ' + entityList[enemyID].race +
        ', but misses');
  end;
end;

end.
