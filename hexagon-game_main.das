require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code


//TODO:
// player and blocks should have shadows
// music (duhh)
// speed on longer sectors seem to be bigger

// decs proved to be too hard to grasp on the fly xP
var vecs: array<float2>

struct Block
    sector: int
    height: float
    position: float
var blocks: array<Block>

var scale = 50.0

let colors_bg1 = 0x303030
let colors_bg2 = 0xD4CDBD
let colors_bg3 = 0x3D3D3D
let colors_hexagon = 0x303030
let colors_edge = 0xD4CDBD
let colors_player = 0x3E93C4
let colors_block = 0xC5A03A
let colors_ui_bg = 0xD4CDBD
let colors_ui_stroke = 0x303030
let colors_ui_text = 0x3E93C4

let font_size = 30.0

var game_hexagonCenter = float2(0.0)
// position relative to game_hexagonCenter
var game_hexagonLightOffset = float2(0.0)
var game_blockLightColor = 0x200000
var game_blockLightOffset = float2(0.0)
var game_cameraAngle = float2(0.0)
var game_paused = true
var game_isMenu = true

let player_size = .2
let player_edge_offset = 0.3
let player_acceleration = 8.0
let player_deacceleration = 4.0
let player_maxSpeed = 8.0

var player_position = 0.5
var player_sector = 0
var player_currentSpeed = 0.0
var player_health = 1
var player_time = 0.0
var player_bestTime = 0.0

let block_speed = 12.0

let block_generator_interval = .7
let block_generator_spawnCount = 3
var block_generator_nextBlockAtTime = 0.0


def get_screen_size()
    return float2(float(get_screen_width()), float(get_screen_height()))

def text_out(x: int; y: int; str: string; color: uint; font_size: int)
    let oldFontSize = get_current_font_size()
    set_font_size(font_size)
    text_out(x,y,str,color)
    set_font_size(oldFontSize)

def vec_from_ang(ang: float)
    return float2(sin(ang), cos(ang))

def rotate_vec(vec: float2; t: float)
    var s, c: float
    sincos(t,s,c)
    return float2(vec.x*c - vec.y*s, vec.x*s + vec.y*c)

def cross(a,b: float2)
    return a.x*b.y - a.y*b.x

// is b between a and c
def is_in_range(a,b,c: float2)
    let AB = b - a
    let AC = c - a
    let BC = c - b
    if dot(AB, AC) < 0.0 || dot(AB, BC) < 0.0
        return false
    
    let norm = cross(normalize(AB), normalize(AC))
    return abs(norm) < 0.0

def fill_sector(center: float2; vec_from, vec_to: float2; color: uint)
    // TODO: fill sector function is trash
    let hsw = float(get_screen_width())/2.0
    let hsh = float(get_screen_height())/2.0
    let big_distance = hsw*hsw + hsh*hsh

    var polygons: array<float2>
    polygons |> push <| center
    polygons |> push <| (center + vec_from*big_distance)

    if is_in_range(vec_from, -center + float2(hsw*2.0, 0.0), vec_to)
        polygons |> push <| float2(float(get_screen_width()), 0.0)
    if length(polygons) == 3
        fill_convex_polygon(polygons, color)
        let tempVec = polygons[2]
        polygons |> clear
        polygons |> push <| center
        polygons |> push <| tempVec
    if is_in_range(vec_from, -center + float2(hsw*2.0, hsh*2.0), vec_to)
        polygons |> push <| float2(float(get_screen_width()), float(get_screen_height()))
    if length(polygons) == 3
        fill_convex_polygon(polygons, color)
        let tempVec = polygons[2]
        polygons |> clear
        polygons |> push <| center
        polygons |> push <| tempVec
    if is_in_range(vec_from, -center + float2(0.0, hsh*2.0), vec_to)
        polygons |> push <| float2(0.0, float(get_screen_height()))
    if length(polygons) == 3
        fill_convex_polygon(polygons, color)
        let tempVec = polygons[2]
        polygons |> clear
        polygons |> push <| center
        polygons |> push <| tempVec
    if is_in_range(vec_from, -center, vec_to)
        polygons |> push <| float2(0.0, 0.0)
    if length(polygons) == 3
        fill_convex_polygon(polygons, color)
        let tempVec = polygons[2]
        polygons |> clear
        polygons |> push <| center
        polygons |> push <| tempVec
        
    polygons |> push <| (center + vec_to*big_distance)
    fill_convex_polygon(polygons, color)

    // circle(center.x, center.y, 3.0, 0xFFFFFF)

    // let scale = 0.5
    // rect(hsw - hsw*scale, hsh - hsh*scale, hsw*2.0*scale, hsh*2.0*scale, 0xFF0000)

    // let scaledCenter = (center - float2(hsw, hsh))*scale + float2(hsw, hsh)
    // line(scaledCenter.x, scaledCenter.y,
    //     scaledCenter.x + vec_from.x*big_distance*scale, scaledCenter.y + vec_from.y*big_distance*scale, 0x0000FF)
    // line(scaledCenter.x, scaledCenter.y,
    //     scaledCenter.x + vec_to.x*big_distance*scale, scaledCenter.y + vec_to.y*big_distance*scale, 0x0000FF)
    // for p in polygons
    //     line(scaledCenter.x, scaledCenter.y,
    //         hsw + (p.x - hsw)*scale, hsh + (p.y - hsh)*scale, 0xFF0000)

// project rotated plane onto (0,0,1) plane (used for simulating camera angled over)
def transform_vec(vec: float2; angle: float2)
    let c = cos(length(angle))
    return float2(
        (c + (1.0-c)*angle.x*angle.x)*vec.x +
        (    (1.0-c)*angle.x*angle.y)*vec.y,
        (    (1.0-c)*angle.x*angle.y)*vec.x +
        (c + (1.0-c)*angle.y*angle.y)*vec.y
    )

def draw_stroked_poly(verts: float2[]; stroke_width: float; stroke_color: uint; fill_color: uint)
    var polyCenter = float2(0.0)
    for v in verts
        polyCenter += v
    polyCenter /= float(length(verts))


    var innerVerts: array<float2>
    for v in verts
        let centeredVec = v - polyCenter
        innerVerts |> push <| (v - float2(sign(centeredVec.x), sign(centeredVec.y))*stroke_width)

    fill_convex_polygon(verts, stroke_color)
    fill_convex_polygon(innerVerts, fill_color)


def fill_plane_with_vecs(amount: int)
    vecs |> clear
    var seed: int4
    randomize_seed(seed)
    for i in range(amount)
        // TODO: non normalized sector vectors break collisions for now
        vecs |> push <| (vec_from_ang(2.0*PI*float(i)/float(amount)))//*(1.0 + random_float(seed)*1.0))

def get_color_by_index(index: int)
    return (index + 0*int(get_time_after_start()))%2 == 0 ? index%2 == 0 && index == length(vecs)-1 ? colors_bg3 : colors_bg1 : colors_bg2

def draw_background()
    let center = game_hexagonCenter + transform_vec(game_hexagonLightOffset, game_cameraAngle)*scale

    fill_sector(center,
        normalize(transform_vec(vecs[length(vecs)-1] - game_hexagonLightOffset, game_cameraAngle)),
        normalize(transform_vec(vecs[0] - game_hexagonLightOffset, game_cameraAngle)),
        get_color_by_index(0))
    for i in range(1, length(vecs))
        fill_sector(center,
            normalize(transform_vec(vecs[i-1] - game_hexagonLightOffset, game_cameraAngle)),
            normalize(transform_vec(vecs[i] - game_hexagonLightOffset, game_cameraAngle)),
            get_color_by_index(i))

def draw_hexagon()
    var polygons: array<float2>
    for v in vecs
        polygons |> push(game_hexagonCenter + transform_vec(v, game_cameraAngle)*scale)
    fill_convex_polygon(polygons, colors_hexagon)
    for i in range(length(polygons))
        line(polygons[i].x, polygons[i].y, polygons[(i+1)%length(polygons)].x, polygons[(i+1)%length(polygons)].y, colors_edge)

struct PlayerPositionData
    center: float2
    baseNormal: float2

def get_player_position_data()
    let v1 = vecs[player_sector] - game_hexagonLightOffset
    let v2 = vecs[(player_sector+1)%length(vecs)] - game_hexagonLightOffset

    let normal = normalize(rotate_vec(v2-v1, PI/2.0))

    var player_center = lerp(v1, v2, player_position)
    player_center += normalize(player_center)*player_edge_offset + normalize(player_center)*player_size*0.5

    return [[PlayerPositionData center = player_center, baseNormal = normal]]

def draw_player()
    let center = game_hexagonCenter + transform_vec(game_hexagonLightOffset, game_cameraAngle)*scale
    let ppd = get_player_position_data()

    let polygons = [[float2
        center + transform_vec(ppd.center + normalize(ppd.center)*player_size, game_cameraAngle)*scale;
        center + transform_vec(ppd.center + rotate_vec(ppd.baseNormal, 2.0*PI/3.0)*player_size, game_cameraAngle)*scale;
        center + transform_vec(ppd.center + rotate_vec(ppd.baseNormal, 4.0*PI/3.0)*player_size, game_cameraAngle)*scale
        ]]
    fill_convex_polygon(polygons, colors_player)

def draw_blocks()
    let center = game_hexagonCenter + transform_vec(game_hexagonLightOffset, game_cameraAngle)*scale
    let lightOffsetVec = transform_vec(game_blockLightOffset, game_cameraAngle)*scale

    for b in blocks
        let v1 = vecs[b.sector] - game_hexagonLightOffset
        let v2 = vecs[(b.sector+1)%length(vecs)] - game_hexagonLightOffset

        let polygons = [[float2
            center + transform_vec(v1*max(1.0, b.position), game_cameraAngle)*scale;
            center + transform_vec(v1*(b.position + b.height), game_cameraAngle)*scale;
            center + transform_vec(v2*(b.position + b.height), game_cameraAngle)*scale;
            center + transform_vec(v2*max(1.0, b.position), game_cameraAngle)*scale
        ]]
        
        var blockCenter = float2(0.0)
        for p in polygons
            blockCenter += p
        blockCenter *= 0.25

        let blockAdditiveColor = multiply_colors(game_blockLightColor, make_color(min(dot(blockCenter - center, lightOffsetVec), 0.7)))
        fill_convex_polygon(polygons, add_colors(colors_block, add_colors(game_blockLightColor, blockAdditiveColor)))


def draw_ui()
    let screenSize = get_screen_size()

    let polySize = float2(300.0, 60.0)
    let stroke = 5.0

    if !game_paused
        let topLeft = -screenSize/2.0
        draw_stroked_poly([[float2
            float2(-stroke) + topLeft;
            float2(polySize.x, -stroke) + topLeft;
            float2(polySize.x, polySize.y) + topLeft;
            float2(-stroke, polySize.y) + topLeft]],
            stroke, colors_ui_stroke, colors_ui_bg)
        text_out(45.0 + topLeft.x, 10.0 + topLeft.y, "Current: {format("%.2f", player_time)}", colors_ui_text)

    let topRight = float2(screenSize.x/2.0, -screenSize.y/2.0)
    draw_stroked_poly([[float2
        float2(-polySize.x, -stroke) + topRight;
        float2(stroke, -stroke) + topRight;
        float2(stroke, polySize.y) + topRight ;
        float2(-polySize.x, polySize.y) + topRight]],
        stroke, colors_ui_stroke, colors_ui_bg)
    text_out(-245.0 + topRight.x, 10.0 + topRight.y, "Best: {format("%.2f", player_bestTime)}", colors_ui_text)

    if game_paused && player_health >= 1
        text_out(-242, -150, "HEXAGON", colors_ui_text, 100)
        text_out(-100, -10, "press Space to start", colors_ui_text, 20)
        text_out(-60, 12, "use A D to move", colors_ui_text, 15)
    elif player_health <= 0
        text_out(-145, -150, "HEXAGON", colors_ui_text, 60)
        text_out(-170, -50, "Your Time: {format("%.2f", player_time)}", colors_ui_text, 45)
        text_out(-100, 22, "press Space to restart", colors_ui_text, 20)


def move_game_field(dt: float)
    // should be level dependant
    if game_paused
        return
    game_hexagonCenter.x = 100.0*sin(get_time_after_start()*5.0/10.0)
    game_hexagonCenter.y = 100.0*sin(get_time_after_start()*4.0/10.0)

    scale = 30.0 + 1.0*abs(sin(get_time_after_start()*6.0)*sin(get_time_after_start()*6.0))

    let rot = -dt*(abs(sin(get_time_after_start()))*0.5 - 1.5)

    for v in vecs
        v = rotate_vec(v, rot)
    game_blockLightOffset = rotate_vec(game_blockLightOffset, rot*2.0)
    game_hexagonLightOffset = rotate_vec(game_hexagonLightOffset, rot)
    game_hexagonLightOffset = rotate_vec(game_hexagonLightOffset, -dt/10.0)

    let screenRotAngle = (PI/3.0)//*abs(sin(get_time_after_start()/1.0))// + (PI/3.0 - PI/4.0)*abs(sin(get_time_after_start()*2.0))
    game_cameraAngle = screenRotAngle * normalize(float2(  cos(get_time_after_start()/10.0),
                                                1.0 + sin(get_time_after_start()/10.0) ))

def _debug_move_light_center()
    if get_mouse_button(MB_LEFT)
        game_blockLightOffset = (get_mouse_position() - game_hexagonCenter)

def get_player_vertical_position()
    return 1.0 + player_edge_offset + player_size

def move_player(dt: float)
    if game_paused
        return
    var moving = false
    if get_key(VK_A) || get_key(VK_LEFT)
        player_currentSpeed += player_acceleration
        moving = true
    
    if get_key(VK_D) || get_key(VK_RIGHT)
        player_currentSpeed -= player_acceleration
        moving = true

    if !moving
        if abs(player_currentSpeed) < player_deacceleration
            player_currentSpeed = 0.0
        else
            player_currentSpeed = (abs(player_currentSpeed) - player_deacceleration)*sign(player_currentSpeed)
    
    player_currentSpeed = clamp(player_currentSpeed, -player_maxSpeed, player_maxSpeed)
    let distMupltiplyer = length(vecs[(player_sector+1)%length(vecs)] - vecs[player_sector])
    player_position += dt*player_currentSpeed/distMupltiplyer

    let playerVerticalPos = get_player_vertical_position()

    let rightSectorId = (player_sector+1)%length(vecs)
    var leftSectorId = player_sector - 1
    if leftSectorId < 0
        leftSectorId = length(vecs)-1

    var blockedLeft = false
    var blockedRight = false
    for b in blocks
        let isOnTheRight = b.sector == rightSectorId
        let isOnTheLeft = b.sector == leftSectorId
        if !isOnTheRight && !isOnTheLeft
            continue
        
        if playerVerticalPos > b.position && playerVerticalPos < b.position + b.height
            if isOnTheRight
                blockedRight = true
            else
                blockedLeft = true

    if player_position < 0.0
        if !blockedLeft
            player_position = 1.0
            player_sector = leftSectorId
        else
            player_position = 0.0

    if player_position > 1.0
        if !blockedRight
            player_position = 0.0
            player_sector = rightSectorId
        else
            player_position = 1.0

def move_blocks(dt: float)
    if game_paused
        return
    let l = length(blocks)-1
    for i in range(l)
        var b& = blocks[l-i]
        b.position -= dt*block_speed
        if b.position + b.height < 0.0
            blocks |> erase <| (l - i)
        
        let playerVerticalPos = get_player_vertical_position()

        if b.sector == player_sector && b.position < playerVerticalPos && b.position + b.height > playerVerticalPos
            player_health -= 1

def create_new_blocks()
    if game_paused
        return
    if block_generator_nextBlockAtTime > get_time_after_start()
        return

    block_generator_nextBlockAtTime = get_time_after_start() + block_generator_interval
    var seed: int4
    randomize_seed(seed)
    for i in range(block_generator_spawnCount)
        let height = 2.0
        let sector = random_int(seed)%length(vecs)
        blocks |> push <| [[Block position = 60.0, height = height, sector = sector]]


def check_death()
    if player_health > 0
        return
    
    if player_bestTime < player_time
        player_bestTime = player_time
        local_storage_set("hexagon-game/best_time", "{player_bestTime}")

    game_paused = true


def start_game()
    game_isMenu = false
    game_paused = false

    game_hexagonLightOffset = float2(0.5)

    player_health = 1
    player_time = 0.0
    player_position = 0.5
    player_sector = 0

    blocks |> clear
    fill_plane_with_vecs(6)

[export]
def initialize(is_hard_reload: bool)
    disable_auto_upscale()
    set_window_title("Not So Super Hexagon")
    set_resolution(1920/2, 1080/2)
    set_antialiasing(4)
    setup_2d_camera(float2(0.0))

    set_font_name("verdana.ttf")
    set_font_size(font_size)

    if local_storage_has_key("hexagon-game/best_time")
        player_bestTime = float(local_storage_get("hexagon-game/best_time"))

    fill_plane_with_vecs(6)


[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key_down(VK_P)
        game_paused = !game_paused

    if get_key_down(VK_R)
        player_bestTime = 0.0
        local_storage_set("hexagon-game/best_time", "{player_bestTime}")

    create_new_blocks()

    move_game_field(dt)
    move_player(dt)
    move_blocks(dt)

    check_death()

    if game_paused && get_key(VK_SPACE)
        start_game()

    if !game_paused
        player_time += dt

    // _debug_move_light_center()
    

[export]
def draw
    draw_background()
    draw_blocks()
    draw_player()
    draw_hexagon()
    draw_ui()
