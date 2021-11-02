require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code


// decs proved to be too hard to grasp on the fly xP
var vecs: array<float2>

struct Block
    sector: int
    height: float
    position: float
var blocks: array<Block>

let scale = 30.0

let colors_bg1 = 0x303030
let colors_bg2 = 0xD4CDBD
let colors_bg3 = 0x3D3D3D
let colors_center = 0x303030
let colors_edge = 0xD4CDBD
let colors_player = 0x000000
let colors_block = 0xC5A03A

var game_shapeCenter = float2(0.0)
// position relative to game_shapeCenter
var game_shapeLightOffset = float2(10.0)
var game_cameraAngle = float2(0.0, 0.0)
var game_paused = false

let player_size = .2
let player_edge_offset = 0.3
let player_acceleration = 8.0
let player_deacceleration = 4.0
let player_maxSpeed = 8.0

var player_position = 0.5
var player_sector = 0
var player_currentSpeed = 0.0
var player_health = 2

let block_speed = 14.0

let block_generator_interval = .7
let block_generator_spawnCount = 3
var block_generator_nextBlockAtTime = 0.0

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
    // cant bother to calculate position on exactly screens edge. This should do in all cases
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

    // TODO: fill sector function is trash
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

def transform_vec(vec: float2; angle: float2)
    let c = cos(length(angle))
    return float2(
        (c + (1.0-c)*angle.x*angle.x)*vec.x +
        (    (1.0-c)*angle.x*angle.y)*vec.y,
        (    (1.0-c)*angle.x*angle.y)*vec.x +
        (c + (1.0-c)*angle.y*angle.y)*vec.y
    )

def fill_plane_with_vecs(amount: int)
    vecs |> clear
    var seed: int4
    randomize_seed(seed)
    for i in range(amount)
        vecs |> push <| (vec_from_ang(2.0*PI*float(i)/float(amount)))//*(1.0 + random_float(seed)*1.0))


def get_center()
    return float2(float(get_screen_width())/2.0, float(get_screen_width())/2.0)

def get_color_by_index(index: int)
    return (index + 0*int(get_time_after_start()))%2 == 0 ? index%2 == 0 && index == length(vecs)-1 ? colors_bg3 : colors_bg1 : colors_bg2

def draw_background()
    let center = get_center() + game_shapeCenter + transform_vec(game_shapeLightOffset, game_cameraAngle)
    let delta = game_shapeLightOffset/scale

    fill_sector(center,
        normalize(transform_vec(vecs[length(vecs)-1] - delta, game_cameraAngle)),
        normalize(transform_vec(vecs[0] - delta, game_cameraAngle)),
        get_color_by_index(0))
    for i in range(1, length(vecs))
        fill_sector(center,
            normalize(transform_vec(vecs[i-1] - delta, game_cameraAngle)),
            normalize(transform_vec(vecs[i] - delta, game_cameraAngle)),
            get_color_by_index(i))
    set_pixel(center.x, center.y, 0x000000)

def draw_shape()
    let center = get_center() + game_shapeCenter

    var polygons: array<float2>
    for v in vecs
        polygons |> push(center + transform_vec(v, game_cameraAngle)*scale)
    fill_convex_polygon(polygons, colors_center)
    for i in range(length(polygons))
        line(polygons[i].x, polygons[i].y, polygons[(i+1)%length(polygons)].x, polygons[(i+1)%length(polygons)].y, colors_edge)

def draw_player()
    let center = get_center() + game_shapeCenter + transform_vec(game_shapeLightOffset, game_cameraAngle)
    let delta = game_shapeLightOffset/scale

    let v1 = vecs[player_sector] - delta
    let v2 = vecs[(player_sector+1)%length(vecs)] - delta

    let normal = normalize(rotate_vec(v2-v1, PI/2.0))

    var player_center = lerp(v1, v2, player_position)
    player_center += normal*player_edge_offset + normal*player_size/2.0


    let polygons = [[float2
        center + transform_vec(player_center + normal*player_size, game_cameraAngle)*scale;
        center + transform_vec(player_center + rotate_vec(normal, 2.0*PI/3.0)*player_size, game_cameraAngle)*scale;
        center + transform_vec(player_center + rotate_vec(normal, 4.0*PI/3.0)*player_size, game_cameraAngle)*scale
        ]]
    fill_convex_polygon(polygons, colors_player)
    return

def draw_blocks()
    let center = get_center() + game_shapeCenter + transform_vec(game_shapeLightOffset, game_cameraAngle)

    for b in blocks
        let v1 = vecs[b.sector] - game_shapeLightOffset/scale
        let v2 = vecs[(b.sector+1)%length(vecs)] - game_shapeLightOffset/scale

        let polygons = [[float2
            center + transform_vec(v1*max(1.0, b.position), game_cameraAngle)*scale;
            center + transform_vec(v1*(b.position + b.height), game_cameraAngle)*scale;
            center + transform_vec(v2*(b.position + b.height), game_cameraAngle)*scale;
            center + transform_vec(v2*max(1.0, b.position), game_cameraAngle)*scale
        ]]
        fill_convex_polygon(polygons, colors_block)


def move_game_field(dt: float)
    if game_paused
        return
    game_shapeCenter.x = 100.0*sin(get_time_after_start()*5.0/10.0)
    game_shapeCenter.y = 100.0*sin(get_time_after_start()*4.0/10.0)

    for v in vecs
        v = rotate_vec(v, -dt*(abs(sin(get_time_after_start()))*0.5 - 1.5))
    game_shapeLightOffset = rotate_vec(game_shapeLightOffset, -dt*(abs(sin(get_time_after_start()))*0.5 - 1.5))
    game_shapeLightOffset = rotate_vec(game_shapeLightOffset, -dt/10.0)

    let screenRotAngle = (PI/3.0)//*abs(sin(get_time_after_start()/1.0))// + (PI/3.0 - PI/4.0)*abs(sin(get_time_after_start()*2.0))
    game_cameraAngle = screenRotAngle * normalize(float2(  cos(get_time_after_start()/10.0),
                                                1.0 + sin(get_time_after_start()/10.0) ))

def _debug_move_light_center()
    if get_mouse_button(MB_LEFT)
        game_shapeLightOffset = (get_mouse_position() - get_center() - game_shapeCenter)

def move_player(dt: float)
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

    if player_position < 0.0
        player_position = 1.0
        player_sector -= 1
        if player_sector < 0
            player_sector = length(vecs)-1

    if player_position > 1.0
        player_position = 0.0
        player_sector = (player_sector+1)%length(vecs)

def move_blocks(dt: float)
    let l = length(blocks)-1
    for i in range(l)
        blocks[l - i].position -= dt*block_speed
        if blocks[l - i].position + blocks[l - i].height < 0.0
            blocks |> erase <| (l - i)

def create_new_blocks()
    if block_generator_nextBlockAtTime > get_time_after_start()
        return

    block_generator_nextBlockAtTime = get_time_after_start() + block_generator_interval
    var seed: int4
    randomize_seed(seed)
    for i in range(block_generator_spawnCount)
        let height = 2.0
        let sector = random_int(seed)%length(vecs)
        blocks |> push <| [[Block position = 60.0, height = height, sector = sector]]



[export]
def initialize(is_hard_reload: bool)
    set_window_title("hexagon-game")
    set_resolution(1000, 1000)
    set_antialiasing(4)

    fill_plane_with_vecs(8)

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key_down(VK_P)
        game_paused = !game_paused

    create_new_blocks()

    move_game_field(dt)
    move_player(dt)
    move_blocks(dt)

    // _debug_move_light_center()
    

[export]
def draw
    draw_background()
    draw_player()
    draw_blocks()
    draw_shape()
