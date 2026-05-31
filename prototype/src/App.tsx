import { useMemo, useState } from 'react'
import './App.css'

type Point = { x: number; y: number }
type TileKind = 'floor' | 'wall' | 'rubble' | 'ember' | 'exit'
type EnemyKind = 'melee' | 'caster'
type GameStatus = 'playing' | 'won' | 'lost'
type LevelSize = 'small' | 'medium'

type Level = {
  seed: string
  size: LevelSize
  width: number
  height: number
  tiles: TileKind[][]
  entrance: Point
  exit: Point
  validation: string
}

type RoomAnchor = {
  x: number
  y: number
  width: number
  height: number
}

type LevelRecipe = {
  width: number
  height: number
  criticalRooms: number
  branchRooms: number
  rubble: number
  embers: number
  enemies: number
}

type Enemy = {
  id: string
  kind: EnemyKind
  name: string
  hp: number
  maxHp: number
  pos: Point
  bleedTurns?: number
  disorientedTurns?: number
  channelTarget?: Point
}

type WeaponId = 'sword' | 'dagger' | 'spear' | 'axe' | 'mace' | 'bow' | 'crossbow' | 'staff' | 'wand'
type SupportId = 'none' | 'tome' | 'shield'

type Weapon = {
  id: WeaponId
  name: string
  range: number
  damage: number
  targeting: string
  special: string
  note: string
}

type SupportItem = {
  id: SupportId
  name: string
  armor: number
  blockChance: number
  note: string
  special: string
}

type Metrics = {
  moves: number
  tilesMoved: number
  attacks: number
  kills: number
  waits: number
  damageTaken: number
}

type GameState = {
  level: Level
  player: Point
  playerHp: number
  enemies: Enemy[]
  status: GameStatus
  weaponId: Weapon['id']
  supportId: SupportId
  log: string[]
  turn: number
  metrics: Metrics
  explored: string[]
}

const movementBudget = 3
const lineOfSightRadius = 4
const playerMaxHp = 18
const defaultSeed = 'phase-3-small'
const defaultLevelSize: LevelSize = 'small'
const zoomSteps = [36, 48, 60, 72]
const defaultTileSize = 48

const levelRecipes: Record<LevelSize, LevelRecipe> = {
  small: {
    width: 8,
    height: 8,
    criticalRooms: 3,
    branchRooms: 1,
    rubble: 2,
    embers: 1,
    enemies: 2,
  },
  medium: {
    width: 14,
    height: 12,
    criticalRooms: 5,
    branchRooms: 3,
    rubble: 5,
    embers: 3,
    enemies: 3,
  },
}

const weapons: Weapon[] = [
  {
    id: 'sword',
    name: 'Sword',
    range: 1,
    damage: 4,
    targeting: 'Adjacent',
    special: 'Reliable hit',
    note: 'Adjacent melee attack. Reliable damage.',
  },
  {
    id: 'dagger',
    name: 'Dagger',
    range: 1,
    damage: 2,
    targeting: 'Adjacent',
    special: 'Unseen damage spike',
    note: 'Lower normal damage. Intended to become the strongest melee hit when Unseen.',
  },
  {
    id: 'spear',
    name: 'Spear',
    range: 2,
    damage: 3,
    targeting: 'Line melee',
    special: 'Reach 2',
    note: 'Melee reach weapon. Less damage than sword, safer spacing.',
  },
  {
    id: 'axe',
    name: 'Axe',
    range: 1,
    damage: 3,
    targeting: 'Adjacent',
    special: '35% bleed',
    note: 'Less damage than sword, with a chance to apply bleeding.',
  },
  {
    id: 'mace',
    name: 'Mace',
    range: 1,
    damage: 3,
    targeting: 'Adjacent',
    special: '35% disorient',
    note: 'Less damage than sword, with a chance to disrupt enemy action.',
  },
  {
    id: 'bow',
    name: 'Bow',
    range: 4,
    damage: 3,
    targeting: 'Line of sight',
    special: '-30% adjacent',
    note: 'Range 4. -30% damage against adjacent enemies.',
  },
  {
    id: 'crossbow',
    name: 'Crossbow',
    range: 3,
    damage: 4,
    targeting: 'Line of sight',
    special: 'Knockback 1',
    note: 'Shorter range and heavy hit. Pushes enemies back when space allows.',
  },
  {
    id: 'staff',
    name: 'Staff',
    range: 4,
    damage: 4,
    targeting: 'Line of sight',
    special: 'Half damage adjacent',
    note: 'Projectile attack. Adjacent hits deal half damage.',
  },
  {
    id: 'wand',
    name: 'Wand',
    range: 4,
    damage: 2,
    targeting: 'Ignores blockers',
    special: 'Instant line',
    note: 'Lower damage, but ignores walls and enemies.',
  },
]

const supportItems: SupportItem[] = [
  {
    id: 'none',
    name: 'None',
    armor: 0,
    blockChance: 0,
    special: 'No support',
    note: 'No off-hand modifier equipped.',
  },
  {
    id: 'tome',
    name: 'Tome',
    armor: 0,
    blockChance: 0,
    special: '+1 staff/wand damage',
    note: 'Tome does not attack. Prototype modifier: staff and wand attacks deal +1 damage.',
  },
  {
    id: 'shield',
    name: 'Shield',
    armor: 1,
    blockChance: 0.5,
    special: '+1 armor, 50% block',
    note: 'Shield grants armor and can block half incoming physical damage.',
  },
]

function formatLevelSize(size: LevelSize) {
  return `${size[0].toUpperCase()}${size.slice(1)}`
}

function createInitialState(seed = defaultSeed, size: LevelSize = defaultLevelSize): GameState {
  const level = generateLevel(seed, size)

  return {
    level,
    player: level.entrance,
    playerHp: playerMaxHp,
    enemies: createEnemiesForLevel(level),
    status: 'playing',
    weaponId: 'sword',
    supportId: 'none',
    log: [
      `Generated ${formatLevelSize(level.size)} level from seed ${level.seed}.`,
      level.validation,
      'Reach the exit after defeating the enemies.',
    ],
    turn: 1,
    metrics: {
      moves: 0,
      tilesMoved: 0,
      attacks: 0,
      kills: 0,
      waits: 0,
      damageTaken: 0,
    },
    explored: Array.from(visibleTilesFrom(level, level.entrance)),
  }
}

function initialConfigFromUrl() {
  const params = new URLSearchParams(window.location.search)
  const seed = params.get('seed')?.trim() || defaultSeed
  const sizeParam = params.get('size')
  const size: LevelSize = sizeParam === 'medium' || sizeParam === 'small' ? sizeParam : defaultLevelSize
  return { seed, size }
}

function writeRunUrl(seed: string, size: LevelSize) {
  const params = new URLSearchParams()
  params.set('seed', seed)
  params.set('size', size)
  window.history.replaceState(null, '', `?${params.toString()}`)
}

function samePoint(a: Point, b: Point) {
  return a.x === b.x && a.y === b.y
}

function pointKey(point: Point) {
  return `${point.x},${point.y}`
}

function distance(a: Point, b: Point) {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y)
}

function hashSeed(seed: string) {
  let hash = 2166136261
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return hash >>> 0
}

function createRng(seed: string) {
  let state = hashSeed(seed)
  return () => {
    state = Math.imul(state + 0x6d2b79f5, 1)
    let result = state
    result = Math.imul(result ^ (result >>> 15), result | 1)
    result ^= result + Math.imul(result ^ (result >>> 7), result | 61)
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296
  }
}

function inBounds(level: Level, point: Point) {
  return point.x >= 0 && point.x < level.width && point.y >= 0 && point.y < level.height
}

function tileAt(level: Level, point: Point) {
  return level.tiles[point.y]?.[point.x]
}

function isBlocked(level: Level, point: Point, enemies: Enemy[]) {
  const tile = tileAt(level, point)
  return tile === 'wall' || tile === 'rubble' || enemies.some((enemy) => samePoint(enemy.pos, point))
}

function isWalkable(tile: TileKind | undefined) {
  return tile === 'floor' || tile === 'ember' || tile === 'exit'
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value))
}

function randomInt(rng: () => number, min: number, max: number) {
  return min + Math.floor(rng() * (max - min + 1))
}

function generateLevel(seed: string, size: LevelSize): Level {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const level = generateLevelCandidate(`${seed}:${size}:${attempt}`, seed, size)
    if (hasWalkablePath(level, level.entrance, level.exit)) {
      const floorCount = collectTiles(level).length
      return {
        ...level,
        validation: `Validation passed after ${attempt + 1} ${attempt === 0 ? 'try' : 'tries'} (${floorCount} walkable tiles).`,
      }
    }
  }

  return fallbackLevel(seed, size)
}

function generateLevelCandidate(rngSeed: string, displaySeed: string, size: LevelSize): Level {
  const rng = createRng(rngSeed)
  const recipe = levelRecipes[size]
  const tiles = Array.from({ length: recipe.height }, () => Array<TileKind>(recipe.width).fill('wall'))
  const anchors = buildCriticalAnchors(rng, recipe, size)

  anchors.forEach((anchor) => carveRoom(tiles, anchor))
  anchors.slice(1).forEach((anchor, index) => {
    carveCorridor(tiles, roomCenter(anchors[index]), roomCenter(anchor), rng)
  })

  addBranchRooms(tiles, anchors, recipe, rng)

  const entrance = { x: 0, y: roomCenter(anchors[0]).y }
  const exit = { x: recipe.width - 1, y: roomCenter(anchors[anchors.length - 1]).y }
  tiles[entrance.y][entrance.x] = 'floor'
  tiles[exit.y][exit.x] = 'exit'

  const level = {
    seed: displaySeed,
    size,
    width: recipe.width,
    height: recipe.height,
    tiles,
    entrance,
    exit,
    validation: '',
  }

  placeEmbers(level, rng, recipe.embers)
  placeRubble(level, rng, recipe.rubble)
  tiles[entrance.y][entrance.x] = 'floor'
  tiles[exit.y][exit.x] = 'exit'

  return level
}

function buildCriticalAnchors(rng: () => number, recipe: LevelRecipe, size: LevelSize) {
  const anchors: RoomAnchor[] = []

  for (let index = 0; index < recipe.criticalRooms; index += 1) {
    const isEdge = index === 0 || index === recipe.criticalRooms - 1
    const width = size === 'small' ? randomInt(rng, 2, 3) : randomInt(rng, 3, 4)
    const height = size === 'small' ? randomInt(rng, 2, 3) : randomInt(rng, 3, 4)
    const progress = index / (recipe.criticalRooms - 1)
    const baseX = Math.round(progress * (recipe.width - width))
    const x = index === 0
      ? 0
      : index === recipe.criticalRooms - 1
        ? recipe.width - width
        : clamp(baseX + randomInt(rng, -1, 1), 1, recipe.width - width - 1)
    const y = randomInt(rng, isEdge ? 1 : 0, Math.max(isEdge ? 1 : 0, recipe.height - height - 1))
    anchors.push({ x, y, width, height })
  }

  return anchors
}

function addBranchRooms(tiles: TileKind[][], anchors: RoomAnchor[], recipe: LevelRecipe, rng: () => number) {
  for (let index = 0; index < recipe.branchRooms; index += 1) {
    const parent = anchors[randomInt(rng, 0, anchors.length - 1)]
    const width = randomInt(rng, 2, recipe.width > 10 ? 4 : 3)
    const height = randomInt(rng, 2, recipe.height > 10 ? 4 : 3)
    const parentCenter = roomCenter(parent)
    const x = clamp(parentCenter.x + randomInt(rng, -4, 4) - Math.floor(width / 2), 1, recipe.width - width - 1)
    const y = clamp(parentCenter.y + randomInt(rng, -4, 4) - Math.floor(height / 2), 1, recipe.height - height - 1)
    const branch = { x, y, width, height }

    carveRoom(tiles, branch)
    carveCorridor(tiles, parentCenter, roomCenter(branch), rng)
  }
}

function roomCenter(room: RoomAnchor): Point {
  return {
    x: room.x + Math.floor(room.width / 2),
    y: room.y + Math.floor(room.height / 2),
  }
}

function carveRoom(tiles: TileKind[][], room: RoomAnchor) {
  for (let y = room.y; y < room.y + room.height; y += 1) {
    for (let x = room.x; x < room.x + room.width; x += 1) {
      tiles[y][x] = 'floor'
    }
  }
}

function carveCorridor(tiles: TileKind[][], from: Point, to: Point, rng: () => number) {
  const carve = (point: Point) => {
    tiles[point.y][point.x] = 'floor'
  }
  const walkHorizontal = (cursor: Point, targetX: number) => {
    while (cursor.x !== targetX) {
      cursor.x += Math.sign(targetX - cursor.x)
      carve(cursor)
    }
  }
  const walkVertical = (cursor: Point, targetY: number) => {
    while (cursor.y !== targetY) {
      cursor.y += Math.sign(targetY - cursor.y)
      carve(cursor)
    }
  }

  const cursor = { ...from }
  carve(cursor)
  if (rng() > 0.5) {
    walkHorizontal(cursor, to.x)
    walkVertical(cursor, to.y)
  } else {
    walkVertical(cursor, to.y)
    walkHorizontal(cursor, to.x)
  }
}

function shuffledPoints(points: Point[], rng: () => number) {
  const shuffled = [...points]
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(rng() * (index + 1))
    const current = shuffled[index]
    shuffled[index] = shuffled[swapIndex]
    shuffled[swapIndex] = current
  }
  return shuffled
}

function placementCandidates(level: Level) {
  return collectTiles(level)
    .filter((point) => distance(point, level.entrance) > 1)
    .filter((point) => distance(point, level.exit) > 1)
}

function placeEmbers(level: Level, rng: () => number, count: number) {
  shuffledPoints(placementCandidates(level), rng)
    .slice(0, count)
    .forEach((point) => {
      level.tiles[point.y][point.x] = 'ember'
    })
}

function placeRubble(level: Level, rng: () => number, count: number) {
  let placed = 0
  const candidates = shuffledPoints(placementCandidates(level), rng)

  for (const point of candidates) {
    if (placed >= count) break
    const previous = level.tiles[point.y][point.x]
    if (previous !== 'floor') continue

    level.tiles[point.y][point.x] = 'rubble'
    if (hasWalkablePath(level, level.entrance, level.exit)) {
      placed += 1
    } else {
      level.tiles[point.y][point.x] = previous
    }
  }
}

function fallbackLevel(seed: string, size: LevelSize): Level {
  const recipe = levelRecipes[size]
  const tiles = Array.from({ length: recipe.height }, () => Array<TileKind>(recipe.width).fill('floor'))
  const entrance = { x: 0, y: recipe.height - 2 }
  const exit = { x: recipe.width - 1, y: 1 }

  for (let x = 2; x < recipe.width - 2; x += 3) {
    const y = clamp(Math.floor(recipe.height / 2), 1, recipe.height - 2)
    tiles[y][x] = 'rubble'
  }

  tiles[entrance.y][entrance.x] = 'floor'
  tiles[exit.y][exit.x] = 'exit'

  return {
    seed,
    size,
    width: recipe.width,
    height: recipe.height,
    tiles,
    entrance,
    exit,
    validation: 'Fallback level used after generator retries.',
  }
}

function collectTiles(level: Level) {
  const points: Point[] = []
  for (let y = 0; y < level.height; y += 1) {
    for (let x = 0; x < level.width; x += 1) {
      if (isWalkable(tileAt(level, { x, y }))) points.push({ x, y })
    }
  }
  return points
}

function hasWalkablePath(level: Level, start: Point, goal: Point) {
  const visited = new Set<string>([pointKey(start)])
  const queue: Point[] = [start]

  while (queue.length > 0) {
    const current = queue.shift()
    if (!current) continue
    if (samePoint(current, goal)) return true

    const neighbors = [
      { x: current.x + 1, y: current.y },
      { x: current.x - 1, y: current.y },
      { x: current.x, y: current.y + 1 },
      { x: current.x, y: current.y - 1 },
    ]

    neighbors.forEach((neighbor) => {
      const key = pointKey(neighbor)
      if (!inBounds(level, neighbor) || visited.has(key) || !isWalkable(tileAt(level, neighbor))) return
      visited.add(key)
      queue.push(neighbor)
    })
  }

  return false
}

function createEnemiesForLevel(level: Level) {
  const candidates = collectTiles(level)
    .filter((point) => !samePoint(point, level.entrance) && !samePoint(point, level.exit))
    .filter((point) => distance(point, level.entrance) >= 4)
    .sort((a, b) => distance(b, level.entrance) - distance(a, level.entrance))
  const enemyCount = levelRecipes[level.size].enemies
  const enemies: Enemy[] = []
  const enemyTemplates = [
    { id: 'guard', kind: 'melee' as const, name: 'Iron Cultist', hp: 10 },
    { id: 'seer', kind: 'caster' as const, name: 'Ash Seer', hp: 8 },
    { id: 'brute', kind: 'melee' as const, name: 'Gate Brute', hp: 12 },
  ]

  for (let index = 0; index < enemyCount; index += 1) {
    const template = enemyTemplates[index % enemyTemplates.length]
    const pos = candidates.find((point) => enemies.every((enemy) => distance(enemy.pos, point) >= 2))
      ?? candidates[index]
      ?? { x: Math.max(0, level.width - 3 - index), y: Math.max(0, level.height - 3) }

    enemies.push({
      id: template.id,
      kind: template.kind,
      name: template.name,
      hp: template.hp,
      maxHp: template.hp,
      pos,
    })
  }

  return enemies
}

function lineBetween(a: Point, b: Point) {
  if (a.x !== b.x && a.y !== b.y) return []

  const points: Point[] = []
  const dx = Math.sign(b.x - a.x)
  const dy = Math.sign(b.y - a.y)
  let cursor = { x: a.x + dx, y: a.y + dy }

  while (!samePoint(cursor, b)) {
    points.push(cursor)
    cursor = { x: cursor.x + dx, y: cursor.y + dy }
  }

  return points
}

function visionLineBetween(a: Point, b: Point) {
  const points: Point[] = []
  let x0 = a.x
  let y0 = a.y
  const x1 = b.x
  const y1 = b.y
  const dx = Math.abs(x1 - x0)
  const dy = Math.abs(y1 - y0)
  const sx = x0 < x1 ? 1 : -1
  const sy = y0 < y1 ? 1 : -1
  let err = dx - dy

  while (x0 !== x1 || y0 !== y1) {
    const e2 = err * 2
    if (e2 > -dy) {
      err -= dy
      x0 += sx
    }
    if (e2 < dx) {
      err += dx
      y0 += sy
    }
    if (x0 !== x1 || y0 !== y1) {
      points.push({ x: x0, y: y0 })
    }
  }

  return points
}

function hasVisionLine(level: Level, a: Point, b: Point) {
  if (distance(a, b) > lineOfSightRadius) return false

  return visionLineBetween(a, b).every((point) => {
    const tile = tileAt(level, point)
    return tile !== 'wall' && tile !== 'rubble'
  })
}

function visibleTilesFrom(level: Level, player: Point) {
  const visible = new Set<string>()

  for (let y = 0; y < level.height; y += 1) {
    for (let x = 0; x < level.width; x += 1) {
      const point = { x, y }
      if (hasVisionLine(level, player, point)) {
        visible.add(pointKey(point))
      }
    }
  }

  return visible
}

function mergeExplored(existing: string[], visible: Set<string>) {
  return Array.from(new Set([...existing, ...visible]))
}

function revealFromPlayer(state: GameState) {
  return {
    ...state,
    explored: mergeExplored(state.explored, visibleTilesFrom(state.level, state.player)),
  }
}

function hasLineOfSight(level: Level, a: Point, b: Point, enemies: Enemy[], ignoresBlockers = false) {
  if (a.x !== b.x && a.y !== b.y) return false
  if (ignoresBlockers) return true

  return lineBetween(a, b).every((point) => {
    const tile = tileAt(level, point)
    const enemyBlocks = enemies.some((enemy) => samePoint(enemy.pos, point))
    return tile !== 'wall' && tile !== 'rubble' && !enemyBlocks
  })
}

function getWeapon(state: GameState) {
  return weapons.find((weapon) => weapon.id === state.weaponId) ?? weapons[0]
}

function getSupport(state: GameState) {
  return supportItems.find((support) => support.id === state.supportId) ?? supportItems[0]
}

function reachableTiles(state: GameState) {
  const visited = new Map<string, number>()
  const queue: Array<{ point: Point; cost: number }> = [{ point: state.player, cost: 0 }]
  visited.set(pointKey(state.player), 0)

  while (queue.length > 0) {
    const current = queue.shift()
    if (!current) continue

    const neighbors = [
      { x: current.point.x + 1, y: current.point.y },
      { x: current.point.x - 1, y: current.point.y },
      { x: current.point.x, y: current.point.y + 1 },
      { x: current.point.x, y: current.point.y - 1 },
    ]

    neighbors.forEach((neighbor) => {
      const nextCost = current.cost + 1
      if (!inBounds(state.level, neighbor) || nextCost > movementBudget) return
      if (isBlocked(state.level, neighbor, state.enemies)) return

      const key = pointKey(neighbor)
      const previous = visited.get(key)
      if (previous === undefined || nextCost < previous) {
        visited.set(key, nextCost)
        queue.push({ point: neighbor, cost: nextCost })
      }
    })
  }

  return visited
}

function attackPreview(state: GameState, enemy: Enemy) {
  const weapon = getWeapon(state)
  const support = getSupport(state)
  const range = distance(state.player, enemy.pos)
  const ignoresBlockers = weapon.id === 'wand'
  const aligned = state.player.x === enemy.pos.x || state.player.y === enemy.pos.y
  const inRange = range <= weapon.range
  const canSee = hasLineOfSight(state.level, state.player, enemy.pos, state.enemies, ignoresBlockers)
  const canAttack = aligned && inRange && canSee
  let damage = weapon.damage
  let reason = 'Ready'
  let effect = weapon.special

  if (support.id === 'tome' && (weapon.id === 'staff' || weapon.id === 'wand')) {
    damage += 1
    effect = `${effect}; Tome +1`
  }
  if (weapon.id === 'dagger' && isPlayerUnseen(state)) {
    damage = Math.ceil(damage * 2.5)
    effect = 'Unseen strike'
  }
  if ((weapon.id === 'bow' || weapon.id === 'crossbow') && range === 1) {
    damage = Math.max(1, Math.floor(damage * 0.7))
    effect = `${effect}; adjacent penalty`
  }
  if (weapon.id === 'staff' && range === 1) damage = Math.max(1, Math.ceil(damage * 0.5))

  if (!aligned) reason = `${weapon.name} needs a straight line.`
  else if (!inRange) reason = `Out of range: ${range}/${weapon.range}.`
  else if (!canSee) reason = `${weapon.name} line is blocked.`

  return { canAttack, damage, effect, range, reason }
}

function isInWeaponLine(state: GameState, point: Point) {
  const weapon = getWeapon(state)
  const tile = tileAt(state.level, point)
  const range = distance(state.player, point)
  const aligned = state.player.x === point.x || state.player.y === point.y
  const canTargetTile = tile !== 'wall' && tile !== 'rubble'

  if (samePoint(state.player, point) || !aligned || range === 0 || range > weapon.range || !canTargetTile) {
    return false
  }

  return hasLineOfSight(state.level, state.player, point, state.enemies, weapon.id === 'wand')
}

function tileName(tile: TileKind | undefined) {
  if (!tile) return 'Unknown'
  return {
    floor: 'Floor',
    wall: 'Wall',
    rubble: 'Rubble',
    ember: 'Ember Hazard',
    exit: 'Exit',
  }[tile]
}

function enemyStatus(enemy: Enemy) {
  const statuses = []
  if (enemy.bleedTurns && enemy.bleedTurns > 0) statuses.push(`Bleed ${enemy.bleedTurns}`)
  if (enemy.disorientedTurns && enemy.disorientedTurns > 0) statuses.push(`Disoriented ${enemy.disorientedTurns}`)
  return statuses.length > 0 ? ` (${statuses.join(', ')})` : ''
}

function enemyCanSeePlayer(enemy: Enemy, state: GameState) {
  return distance(enemy.pos, state.player) <= lineOfSightRadius && hasLineOfSight(state.level, enemy.pos, state.player, state.enemies)
}

function isPlayerUnseen(state: GameState) {
  return !state.enemies.some((enemy) => enemyCanSeePlayer(enemy, state))
}

function applyPhysicalDamage(amount: number, state: GameState) {
  const support = getSupport(state)
  let damage = Math.max(0, amount - support.armor)
  let blocked = false

  if (support.blockChance > 0 && Math.random() < support.blockChance) {
    damage = Math.ceil(damage / 2)
    blocked = true
  }

  return { blocked, damage }
}

function describeTile(
  state: GameState,
  point: Point,
  reachable: Map<string, number>,
  visible: Set<string>,
  explored: Set<string>,
) {
  const key = pointKey(point)
  const isVisible = visible.has(key)
  const isExplored = explored.has(key)
  const tile = tileAt(state.level, point)
  const rows: Array<{ label: string; value: string }> = [
    { label: 'Tile', value: `${point.x + 1},${point.y + 1}` },
  ]
  let note = ''

  if (!isExplored) {
    rows.push({ label: 'Visibility', value: 'Unexplored' })
    return { rows, note: 'Black fog hides terrain and occupants.' }
  }

  const enemy = isVisible ? state.enemies.find((current) => samePoint(current.pos, point)) : undefined
  const moveCost = reachable.get(key)
  const channelingEnemy = isVisible
    ? state.enemies.find((current) => current.channelTarget && samePoint(current.channelTarget, point))
    : undefined

  rows.push({ label: 'Terrain', value: tileName(tile) })
  rows.push({ label: 'Visibility', value: isVisible ? 'Visible' : 'Remembered' })

  if (samePoint(state.player, point)) {
    rows.push({ label: 'Occupant', value: 'You' })
  } else if (enemy) {
    const preview = attackPreview(state, enemy)
    rows.push({ label: 'Occupant', value: `${enemy.name} (${enemy.hp}/${enemy.maxHp} HP)${enemyStatus(enemy)}` })
    rows.push({
      label: 'Attack',
      value: preview.canAttack ? `${getWeapon(state).name} for ${preview.damage}` : preview.reason,
    })
    if (preview.canAttack) rows.push({ label: 'Effect', value: preview.effect })
  } else if (moveCost !== undefined) {
    rows.push({ label: 'Move', value: moveCost === 0 ? 'Current tile' : `${moveCost} tiles` })
  } else if (tile === 'wall' || tile === 'rubble') {
    rows.push({ label: 'Move', value: 'Blocked' })
  } else {
    rows.push({ label: 'Move', value: 'Out of reach this turn' })
  }

  if (isVisible && !enemy && isInWeaponLine(state, point)) {
    rows.push({ label: 'Weapon Line', value: `${getWeapon(state).name} can reach` })
  }

  if (channelingEnemy) {
    note = `${channelingEnemy.name} has marked this tile. Move before the enemy turn.`
  } else if (tile === 'ember') {
    note = 'Standing here after moving burns you for 1 HP.'
  } else if (tile === 'exit' && state.enemies.length > 0) {
    note = 'The exit opens after all enemies are defeated.'
  } else if (tile === 'exit') {
    note = 'The exit is open.'
  } else if (!isVisible) {
    note = 'Remembered terrain is shown, but live occupants are hidden.'
  }

  return { rows, note }
}

function appendLog(log: string[], entry: string) {
  return [entry, ...log].slice(0, 6)
}

function findStepToward(level: Level, start: Point, target: Point, enemies: Enemy[]) {
  const options = [
    { x: start.x + 1, y: start.y },
    { x: start.x - 1, y: start.y },
    { x: start.x, y: start.y + 1 },
    { x: start.x, y: start.y - 1 },
  ]
    .filter((point) => inBounds(level, point))
    .filter((point) => !samePoint(point, target))
    .filter((point) => !isBlocked(level, point, enemies.filter((enemy) => !samePoint(enemy.pos, start))))
    .sort((a, b) => distance(a, target) - distance(b, target))

  return options[0] ?? start
}

function knockbackPoint(player: Point, target: Point) {
  return {
    x: target.x + Math.sign(target.x - player.x),
    y: target.y + Math.sign(target.y - player.y),
  }
}

function canEnemyMoveTo(level: Level, point: Point, enemies: Enemy[], movingEnemyId: string) {
  if (!inBounds(level, point)) return false
  const tile = tileAt(level, point)
  if (tile === 'wall' || tile === 'rubble') return false
  return !enemies.some((enemy) => enemy.id !== movingEnemyId && samePoint(enemy.pos, point))
}

function processEnemies(state: GameState): GameState {
  if (state.status !== 'playing') return state

  let playerHp = state.playerHp
  let enemies = state.enemies.map((enemy) => ({ ...enemy }))
  let log = state.log
  let metrics = { ...state.metrics }

  enemies = enemies.map((enemy) => {
    if (!enemy.bleedTurns || enemy.bleedTurns <= 0) return enemy

    const hp = enemy.hp - 1
    log = appendLog(log, `${enemy.name} bleeds for 1.`)
    return {
      ...enemy,
      hp,
      bleedTurns: Math.max(0, enemy.bleedTurns - 1),
    }
  })

  const bleedKills = enemies.filter((enemy) => enemy.hp <= 0).length
  if (bleedKills > 0) {
    metrics = { ...metrics, kills: metrics.kills + bleedKills }
    log = appendLog(log, `${bleedKills === 1 ? 'An enemy falls' : `${bleedKills} enemies fall`} from bleeding.`)
    enemies = enemies.filter((enemy) => enemy.hp > 0)
  }

  enemies = enemies.map((enemy) => {
    if (enemy.disorientedTurns && enemy.disorientedTurns > 0) {
      log = appendLog(log, `${enemy.name} loses its action while disoriented.`)
      return { ...enemy, disorientedTurns: Math.max(0, enemy.disorientedTurns - 1) }
    }

    if (enemy.kind === 'melee') {
      if (distance(enemy.pos, state.player) === 1) {
        const result = applyPhysicalDamage(3, state)
        playerHp -= result.damage
        metrics = { ...metrics, damageTaken: metrics.damageTaken + result.damage }
        log = appendLog(
          log,
          result.blocked
            ? `${enemy.name} strikes, but your shield blocks it down to ${result.damage}.`
            : `${enemy.name} strikes you for ${result.damage}.`,
        )
        return enemy
      }

      const nextPos = findStepToward(state.level, enemy.pos, state.player, enemies)
      if (!samePoint(nextPos, enemy.pos)) {
        log = appendLog(log, `${enemy.name} advances.`)
      }
      return { ...enemy, pos: nextPos }
    }

    if (enemy.channelTarget) {
      if (samePoint(enemy.channelTarget, state.player)) {
        playerHp -= 4
        metrics = { ...metrics, damageTaken: metrics.damageTaken + 4 }
        log = appendLog(log, `${enemy.name}'s ember sigil detonates for 4.`)
      } else {
        log = appendLog(log, `${enemy.name}'s ember sigil misses.`)
      }
      return { ...enemy, channelTarget: undefined }
    }

    if (distance(enemy.pos, state.player) <= 5 && hasLineOfSight(state.level, enemy.pos, state.player, enemies)) {
      log = appendLog(log, `${enemy.name} marks your tile.`)
      return { ...enemy, channelTarget: state.player }
    }

    const nextPos = findStepToward(state.level, enemy.pos, state.player, enemies)
    if (!samePoint(nextPos, enemy.pos)) {
      log = appendLog(log, `${enemy.name} searches for sightline.`)
    }
    return { ...enemy, pos: nextPos }
  })

  return {
    ...state,
    enemies,
    playerHp,
    status: playerHp <= 0 ? 'lost' : state.status,
    log: playerHp <= 0 ? appendLog(log, 'You fall in the sealed level.') : log,
    metrics,
  }
}

function App() {
  const [state, setState] = useState<GameState>(() => {
    const config = initialConfigFromUrl()
    return createInitialState(config.seed, config.size)
  })
  const [inspected, setInspected] = useState<Point>(() => state.player)
  const [seedDraft, setSeedDraft] = useState(() => state.level.seed)
  const [tileSize, setTileSize] = useState(defaultTileSize)

  const reachable = useMemo(() => reachableTiles(state), [state])
  const visible = useMemo(() => visibleTilesFrom(state.level, state.player), [state.level, state.player])
  const explored = useMemo(() => new Set(state.explored), [state.explored])
  const weapon = getWeapon(state)
  const support = getSupport(state)
  const exitOpen = state.enemies.length === 0
  const selectedSeed = state.level.seed
  const visibleEnemyCount = state.enemies.filter((enemy) => visible.has(pointKey(enemy.pos))).length
  const playerUnseen = isPlayerUnseen(state)
  const levelSizeLabel = `${formatLevelSize(state.level.size)} ${state.level.width}x${state.level.height}`
  const zoomIndex = zoomSteps.indexOf(tileSize)
  const zoomLabel = `${Math.round((tileSize / defaultTileSize) * 100)}%`
  const inspectedDetails = useMemo(
    () => describeTile(state, inspected, reachable, visible, explored),
    [explored, inspected, reachable, state, visible],
  )
  const statusCopy = {
    playing: {
      title: 'Playtest Active',
      body: 'Use this level to test movement pressure, weapon readability, generator readability, and enemy response.',
    },
    won: {
      title: 'Level Cleared',
      body: 'Good. Now replay it aggressively or cautiously and compare the metrics.',
    },
    lost: {
      title: 'Run Failed',
      body: 'Useful failure: the log and metrics should make the mistake readable.',
    },
  }[state.status]

  function commit(nextState: GameState) {
    const afterHazard = tileAt(nextState.level, nextState.player) === 'ember'
      ? {
          ...nextState,
          playerHp: nextState.playerHp - 1,
          metrics: {
            ...nextState.metrics,
            damageTaken: nextState.metrics.damageTaken + 1,
          },
          log: appendLog(nextState.log, 'Embers burn you for 1.'),
        }
      : nextState

    const afterEnemies = processEnemies({ ...afterHazard, turn: afterHazard.turn + 1 })

    setState({
      ...afterEnemies,
      explored: mergeExplored(afterEnemies.explored, visibleTilesFrom(afterEnemies.level, afterEnemies.player)),
      status: afterEnemies.playerHp <= 0 ? 'lost' : afterEnemies.status,
    })
  }

  function moveTo(point: Point) {
    if (state.status !== 'playing') return
    const key = pointKey(point)
    if (!reachable.has(key) || samePoint(point, state.player)) return
    if (!visible.has(key)) return
    const tile = tileAt(state.level, point)
    const moveCost = reachable.get(key) ?? 0
    const metrics = {
      ...state.metrics,
      moves: state.metrics.moves + 1,
      tilesMoved: state.metrics.tilesMoved + moveCost,
    }
    setInspected(point)

    if (tile === 'exit' && exitOpen) {
      setState(revealFromPlayer({
        ...state,
        player: point,
        status: 'won',
        metrics,
        log: appendLog(state.log, 'You escape the level.'),
      }))
      return
    }
    if (tile === 'exit' && !exitOpen) {
      setState({ ...state, log: appendLog(state.log, 'The exit is sealed until the enemies fall.') })
      return
    }

    commit({
      ...state,
      player: point,
      metrics,
      log: appendLog(state.log, `You move ${moveCost} tiles.`),
    })
  }

  function attackEnemy(enemy: Enemy) {
    if (state.status !== 'playing') return
    setInspected(enemy.pos)
    const preview = attackPreview(state, enemy)
    if (!preview.canAttack) {
      setState({ ...state, log: appendLog(state.log, `${weapon.name} cannot reach ${enemy.name}.`) })
      return
    }

    let resolvedEffect = preview.effect
    const defeatedCount = enemy.hp - preview.damage <= 0 ? 1 : 0
    const axeBleedApplied = weapon.id === 'axe' && defeatedCount === 0 && Math.random() < 0.35
    const maceDisorientApplied = weapon.id === 'mace' && defeatedCount === 0 && Math.random() < 0.35
    if (weapon.id === 'axe') resolvedEffect = axeBleedApplied ? 'Bleed applied' : 'Bleed did not apply'
    if (weapon.id === 'mace') resolvedEffect = maceDisorientApplied ? 'Disorient applied' : 'Disorient did not apply'

    let nextEnemies = state.enemies.map((current) => {
      if (current.id !== enemy.id) return current

      return {
        ...current,
        hp: current.hp - preview.damage,
        bleedTurns: axeBleedApplied ? 2 : current.bleedTurns,
        disorientedTurns: maceDisorientApplied ? 1 : current.disorientedTurns,
      }
    })

    if (weapon.id === 'crossbow' && defeatedCount === 0) {
      const targetAfterDamage = nextEnemies.find((current) => current.id === enemy.id)
      if (targetAfterDamage) {
        const pushed = knockbackPoint(state.player, targetAfterDamage.pos)
        if (canEnemyMoveTo(state.level, pushed, nextEnemies, targetAfterDamage.id)) {
          nextEnemies = nextEnemies.map((current) =>
            current.id === targetAfterDamage.id ? { ...current, pos: pushed } : current,
          )
          resolvedEffect = 'Knockback 1'
        } else {
          resolvedEffect = 'Knockback blocked'
        }
      }
    }

    const enemies = nextEnemies.filter((current) => current.hp > 0)
    const effectLog =
      defeatedCount > 0
        ? `${weapon.name} defeats ${enemy.name}.`
        : `${weapon.name} hits ${enemy.name} for ${preview.damage}. ${resolvedEffect}.`

    commit({
      ...state,
      enemies,
      metrics: {
        ...state.metrics,
        attacks: state.metrics.attacks + 1,
        kills: state.metrics.kills + defeatedCount,
      },
      log: appendLog(state.log, effectLog),
    })
  }

  function waitTurn() {
    if (state.status !== 'playing') return
    commit({
      ...state,
      metrics: { ...state.metrics, waits: state.metrics.waits + 1 },
      log: appendLog(state.log, 'You hold position.'),
    })
  }

  function reset() {
    const nextState = createInitialState(state.level.seed, state.level.size)
    setState(nextState)
    setInspected(nextState.player)
  }

  function loadSeed(seed: string, size = state.level.size) {
    const nextSeed = seed.trim() || defaultSeed
    const nextState = createInitialState(nextSeed, size)
    setState(nextState)
    setInspected(nextState.player)
    setSeedDraft(nextSeed)
    writeRunUrl(nextSeed, size)
  }

  function loadSize(size: LevelSize) {
    loadSeed(seedDraft || state.level.seed, size)
  }

  function generateNextLevel() {
    const nextSeed = `${defaultSeed}-${state.level.size}-${state.turn}-${Math.floor(Math.random() * 9999)}`
    loadSeed(nextSeed, state.level.size)
  }

  function changeZoom(direction: -1 | 1) {
    const nextIndex = clamp(zoomIndex + direction, 0, zoomSteps.length - 1)
    setTileSize(zoomSteps[nextIndex])
  }

  const cells = []
  for (let y = 0; y < state.level.height; y += 1) {
    for (let x = 0; x < state.level.width; x += 1) {
      const point = { x, y }
      const tile = tileAt(state.level, point)
      const isPlayer = samePoint(state.player, point)
      const key = pointKey(point)
      const isVisible = visible.has(key)
      const isExplored = explored.has(key)
      const enemy = isVisible ? state.enemies.find((current) => samePoint(current.pos, point)) : undefined
      const moveCost = reachable.get(key)
      const isReachable = moveCost !== undefined && !isPlayer && isVisible
      const isExitOpen = tile === 'exit' && exitOpen && isVisible
      const channeling = isVisible && state.enemies.some(
        (current) => current.channelTarget && samePoint(current.channelTarget, point),
      )
      const preview = enemy ? attackPreview(state, enemy) : undefined
      const isWeaponLine = isVisible && isInWeaponLine(state, point)
      const isInspected = samePoint(inspected, point)

      cells.push(
        <button
          className={[
            'tile',
            `tile-${tile}`,
            isReachable ? 'is-reachable' : '',
            isPlayer ? 'has-player' : '',
            enemy ? 'has-enemy' : '',
            isVisible ? 'is-visible' : '',
            isExplored && !isVisible ? 'is-memory' : '',
            !isExplored ? 'is-unexplored' : '',
            isWeaponLine ? 'is-weapon-line' : '',
            preview?.canAttack ? 'can-attack' : '',
            channeling ? 'is-targeted' : '',
            isExitOpen ? 'is-open' : '',
            isInspected ? 'is-inspected' : '',
          ].join(' ')}
          key={key}
          onClick={() => (enemy ? attackEnemy(enemy) : moveTo(point))}
          onFocus={() => setInspected(point)}
          onPointerEnter={() => setInspected(point)}
          type="button"
          aria-label={`${isExplored ? tileName(tile) : 'Unexplored'} tile ${x + 1},${y + 1}`}
        >
          <span className="tile-ground" />
          <span className="fog-layer" />
          {channeling ? <span className="sigil" /> : null}
          {isReachable && !enemy && !isPlayer ? <span className="move-cost">{moveCost}</span> : null}
          {isPlayer ? (
            <span className="piece player-piece" aria-label="Player">
              <svg viewBox="0 0 64 64" role="img">
                <path d="M32 8 48 18v18c0 11-7 18-16 22-9-4-16-11-16-22V18L32 8Z" />
                <path d="M32 19v29M22 30h20" />
              </svg>
            </span>
          ) : null}
          {enemy ? (
            <span className={`piece enemy-piece enemy-${enemy.kind}`} aria-label={enemy.name}>
              <svg viewBox="0 0 64 64" role="img">
                {enemy.kind === 'melee' ? (
                  <>
                    <path d="M18 24 32 10l14 14-6 28H24L18 24Z" />
                    <path d="m24 31 6 5 11-13" />
                  </>
                ) : (
                  <>
                    <path d="M32 8 50 30 32 56 14 30 32 8Z" />
                    <path d="M24 30h16M32 20v22" />
                  </>
                )}
              </svg>
              <span className="enemy-hp" style={{ ['--hp' as string]: enemy.hp / enemy.maxHp }} />
            </span>
          ) : null}
          {preview?.canAttack ? <span className="damage-preview">{preview.damage}</span> : null}
        </button>,
      )
    }
  }

  return (
    <main className="app-shell">
      <section className="game-stage" aria-label="Tactical level prototype">
        <div className="hud hud-top">
          <div>
            <h1>Ashen Gate {formatLevelSize(state.level.size)} Level</h1>
            <p>Seed: {selectedSeed}</p>
          </div>
          <div className={`status-pill status-${state.status}`}>
            {state.status === 'playing' ? `Turn ${state.turn}` : state.status === 'won' ? 'Escaped' : 'Defeated'}
          </div>
        </div>

        <div className="map-shell">
          <div className="map-tools">
            <div className="segmented-control" aria-label="Level size">
              {(['small', 'medium'] as LevelSize[]).map((size) => (
                <button
                  className={state.level.size === size ? 'is-selected' : ''}
                  key={size}
                  onClick={() => loadSize(size)}
                  type="button"
                >
                  {formatLevelSize(size)}
                </button>
              ))}
            </div>
            <div className="zoom-control" aria-label="Map zoom">
              <button
                aria-label="Zoom out"
                disabled={zoomIndex === 0}
                onClick={() => changeZoom(-1)}
                type="button"
              >
                -
              </button>
              <span>{zoomLabel}</span>
              <button
                aria-label="Zoom in"
                disabled={zoomIndex === zoomSteps.length - 1}
                onClick={() => changeZoom(1)}
                type="button"
              >
                +
              </button>
            </div>
          </div>
          <div className="board-wrap">
            <div
              className="board"
              style={{
                ['--grid-width' as string]: state.level.width,
                ['--grid-height' as string]: state.level.height,
                ['--tile-size' as string]: `${tileSize}px`,
              }}
            >
              {cells}
            </div>
          </div>
        </div>

        <div className="hud hud-bottom">
          <div className="vitals">
            <span>HP</span>
            <strong>
              {Math.max(0, state.playerHp)} / {playerMaxHp}
            </strong>
            <div className="hp-bar">
              <span style={{ width: `${Math.max(0, state.playerHp / playerMaxHp) * 100}%` }} />
            </div>
          </div>

          <div className="weapon-rack" aria-label="Weapon selection">
            {weapons.map((item) => (
              <button
                className={item.id === state.weaponId ? 'weapon is-selected' : 'weapon'}
                key={item.id}
                onClick={() => setState({ ...state, weaponId: item.id })}
                type="button"
              >
                <span>{item.name}</span>
                <small>
                  {item.damage} dmg / R{item.range}
                </small>
              </button>
            ))}
          </div>

          <div className="support-rack" aria-label="Support selection">
            {supportItems.map((item) => (
              <button
                className={item.id === state.supportId ? 'support is-selected' : 'support'}
                key={item.id}
                onClick={() => setState({ ...state, supportId: item.id })}
                type="button"
              >
                <span>{item.name}</span>
                <small>{item.special}</small>
              </button>
            ))}
          </div>

          <div className="actions">
            <button onClick={waitTurn} type="button" disabled={state.status !== 'playing'}>
              Wait
            </button>
            <button onClick={reset} type="button">
              Restart
            </button>
            <button onClick={generateNextLevel} type="button">
              New Seed
            </button>
          </div>
        </div>
      </section>

      <aside className="side-panel" aria-label="Combat details">
        <section className={`outcome-card outcome-${state.status}`}>
          <h2>{statusCopy.title}</h2>
          <p>{statusCopy.body}</p>
          {state.status !== 'playing' ? (
            <button className="panel-action" onClick={reset} type="button">
              Restart Level
            </button>
          ) : null}
        </section>

        <section>
          <h2>Generator</h2>
          <dl>
            <div>
              <dt>Size</dt>
              <dd>{levelSizeLabel}</dd>
            </div>
            <div>
              <dt>Seed</dt>
              <dd className="seed-value">{state.level.seed}</dd>
            </div>
            <div>
              <dt>Validation</dt>
              <dd>{state.level.validation}</dd>
            </div>
          </dl>
          <form
            className="seed-form"
            onSubmit={(event) => {
              event.preventDefault()
              loadSeed(seedDraft)
            }}
          >
            <input
              aria-label="Level seed"
              onChange={(event) => setSeedDraft(event.target.value)}
              spellCheck={false}
              type="text"
              value={seedDraft}
            />
            <button type="submit">Load Seed</button>
          </form>
        </section>

        <section className="weapon-card">
          <h2>{weapon.name}</h2>
          <dl className="weapon-stats">
            <div>
              <dt>Damage</dt>
              <dd>{weapon.damage}</dd>
            </div>
            <div>
              <dt>Range</dt>
              <dd>{weapon.range}</dd>
            </div>
            <div>
              <dt>Targeting</dt>
              <dd>{weapon.targeting}</dd>
            </div>
            <div>
              <dt>Special</dt>
              <dd>{weapon.special}</dd>
            </div>
          </dl>
          <p>{weapon.note}</p>
        </section>

        <section className="weapon-card">
          <h2>{support.name}</h2>
          <dl className="weapon-stats">
            <div>
              <dt>Armor</dt>
              <dd>{support.armor}</dd>
            </div>
            <div>
              <dt>Block</dt>
              <dd>{support.blockChance > 0 ? `${Math.round(support.blockChance * 100)}%` : 'None'}</dd>
            </div>
            <div>
              <dt>Special</dt>
              <dd>{support.special}</dd>
            </div>
          </dl>
          <p>{support.note}</p>
        </section>

        <section>
          <h2>Tile Readout</h2>
          <dl>
            {inspectedDetails.rows.map((row) => (
              <div key={row.label}>
                <dt>{row.label}</dt>
                <dd>{row.value}</dd>
              </div>
            ))}
          </dl>
          {inspectedDetails.note ? <p className="readout-note">{inspectedDetails.note}</p> : null}
        </section>

        <section>
          <h2>Level State</h2>
          <dl>
            <div>
              <dt>Move</dt>
              <dd>{movementBudget} tiles</dd>
            </div>
            <div>
              <dt>Sight</dt>
              <dd>{lineOfSightRadius} tiles</dd>
            </div>
            <div>
              <dt>Visible Enemies</dt>
              <dd>{visibleEnemyCount}</dd>
            </div>
            <div>
              <dt>Unseen</dt>
              <dd>{playerUnseen ? 'Yes' : 'No'}</dd>
            </div>
            <div>
              <dt>Exit</dt>
              <dd>{exitOpen ? 'Open' : 'Sealed'}</dd>
            </div>
          </dl>
        </section>

        <section>
          <h2>Playtest Metrics</h2>
          <dl>
            <div>
              <dt>Turns</dt>
              <dd>{state.turn}</dd>
            </div>
            <div>
              <dt>Moves</dt>
              <dd>
                {state.metrics.moves} / {state.metrics.tilesMoved} tiles
              </dd>
            </div>
            <div>
              <dt>Attacks</dt>
              <dd>{state.metrics.attacks}</dd>
            </div>
            <div>
              <dt>Damage Taken</dt>
              <dd>{state.metrics.damageTaken}</dd>
            </div>
          </dl>
        </section>

        <section>
          <h2>Log</h2>
          <ol className="combat-log">
            {state.log.map((entry, index) => (
              <li key={`${entry}-${index}`}>{entry}</li>
            ))}
          </ol>
        </section>
      </aside>
    </main>
  )
}

export default App
