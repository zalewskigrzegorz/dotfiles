return {
    purple = 0xff9580ff,
    black = 0xff22212c,           
    white = 0xfff8f8f2,           
    red = 0xffff9580,             
    green = 0xff8aff80,           
    blue = 0xff80ffea,            
    yellow = 0xffffff80,          
    orange = 0xffffca80,          
    magenta = 0xffff80bf,         
    grey = 0xff7970a9,            
    light_grey = 0xffc6c6c2,      
    dark_grey = 0xff454158,       
    bright_red = 0xffffaa99,      
    bright_green = 0xffa2ff99,    
    transparent = 0x00000000,

    bar = {
        bg = 0xd022212c,
        border = 0xff504c67
    },
    popup = {
        bg = 0xc022212c,
        border = 0xff9580ff
    },
    bg1 = 0xff22212c,
    bg2 = 0xff454158,

    rainbow = {0xffff9580, 0xff8aff80, 0xff9580ff, 0xffffff80, 0xffffca80, 0xffff80bf, 0xff80ffea, 0xffaa99ff},

    with_alpha = function(color, alpha)
        if alpha > 1.0 or alpha < 0.0 then
            return color
        end
        return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
    end
}
