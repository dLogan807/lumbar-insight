classdef CustomColourMaps
    %Data class for defining custom colormaps

    properties (Constant)
        TrafficLight uint8 = [255, 57, 0;
                              255, 59, 0;
                              255, 60, 0;
                              255, 62, 0;
                              255, 63, 0;
                              255, 65, 0;
                              255, 66, 0;
                              255, 68, 0;
                              255, 69, 0;
                              255, 71, 0;
                              255, 72, 0;
                              255, 74, 0;
                              255, 75, 0;
                              255, 77, 0;
                              255, 78, 0;
                              255, 80, 0;
                              255, 81, 0;
                              255, 83, 0;
                              255, 84, 0;
                              255, 86, 0;
                              255, 87, 0;
                              255, 89, 0;
                              255, 91, 0;
                              255, 92, 0;
                              255, 94, 0;
                              255, 95, 0;
                              255, 97, 0;
                              255, 98, 0;
                              255, 100, 0;
                              255, 101, 0;
                              255, 103, 0;
                              255, 104, 0;
                              255, 106, 0;
                              255, 107, 0;
                              255, 109, 0;
                              255, 110, 0;
                              255, 112, 0;
                              255, 113, 0;
                              255, 115, 0;
                              255, 116, 0;
                              255, 118, 0;
                              255, 119, 0;
                              255, 121, 0;
                              255, 122, 0;
                              255, 124, 0;
                              255, 125, 0;
                              255, 127, 0;
                              255, 128, 0;
                              255, 130, 0;
                              255, 131, 0;
                              255, 133, 0;
                              255, 134, 0;
                              255, 136, 0;
                              255, 137, 0;
                              255, 139, 0;
                              255, 141, 0;
                              255, 142, 0;
                              255, 144, 0;
                              255, 145, 0;
                              255, 147, 0;
                              255, 148, 0;
                              255, 150, 0;
                              255, 151, 0;
                              255, 153, 0;
                              255, 154, 0;
                              255, 156, 0;
                              255, 157, 0;
                              255, 159, 0;
                              255, 161, 0;
                              255, 162, 0;
                              255, 164, 0;
                              255, 165, 0;
                              255, 167, 0;
                              255, 169, 0;
                              255, 170, 0;
                              255, 172, 0;
                              255, 173, 0;
                              255, 175, 0;
                              255, 177, 0;
                              255, 178, 0;
                              255, 180, 0;
                              255, 181, 0;
                              255, 183, 0;
                              255, 185, 0;
                              255, 186, 0;
                              255, 188, 0;
                              255, 189, 0;
                              255, 191, 0;
                              255, 193, 0;
                              255, 194, 0;
                              255, 196, 0;
                              255, 197, 0;
                              255, 199, 0;
                              255, 201, 0;
                              255, 202, 0;
                              255, 204, 0;
                              255, 205, 0;
                              255, 207, 0;
                              255, 209, 0;
                              255, 210, 0;
                              255, 212, 0;
                              255, 213, 0;
                              255, 215, 0;
                              255, 217, 0;
                              255, 218, 0;
                              255, 220, 0;
                              255, 221, 0;
                              255, 223, 0;
                              255, 225, 0;
                              255, 226, 0;
                              255, 228, 0;
                              255, 229, 0;
                              255, 231, 0;
                              255, 233, 0;
                              255, 234, 0;
                              255, 236, 0;
                              255, 237, 0;
                              255, 239, 0;
                              255, 241, 0;
                              255, 242, 0;
                              255, 244, 0;
                              255, 245, 0;
                              255, 247, 0;
                              255, 249, 0;
                              255, 250, 0;
                              255, 252, 0;
                              255, 253, 0;
                              255, 255, 0;
                              255, 255, 0;
                              253, 255, 0;
                              252, 255, 0;
                              250, 255, 0;
                              249, 255, 0;
                              247, 255, 0;
                              245, 255, 0;
                              244, 255, 0;
                              242, 255, 0;
                              240, 255, 0;
                              239, 255, 0;
                              237, 255, 0;
                              236, 255, 0;
                              234, 255, 0;
                              232, 255, 0;
                              231, 255, 0;
                              229, 255, 0;
                              228, 255, 0;
                              226, 255, 0;
                              224, 255, 0;
                              223, 255, 0;
                              221, 255, 0;
                              220, 255, 0;
                              218, 255, 0;
                              216, 255, 0;
                              215, 255, 0;
                              213, 255, 0;
                              211, 255, 0;
                              210, 255, 0;
                              208, 255, 0;
                              207, 255, 0;
                              205, 255, 0;
                              203, 255, 0;
                              202, 255, 0;
                              200, 255, 0;
                              199, 255, 0;
                              197, 255, 0;
                              195, 255, 0;
                              194, 255, 0;
                              192, 255, 0;
                              190, 255, 0;
                              189, 255, 0;
                              187, 255, 0;
                              186, 255, 0;
                              184, 255, 0;
                              182, 255, 0;
                              181, 255, 0;
                              179, 255, 0;
                              178, 255, 0;
                              176, 255, 0;
                              174, 255, 0;
                              173, 255, 0;
                              171, 255, 0;
                              170, 255, 0;
                              168, 255, 0;
                              166, 255, 0;
                              165, 255, 0;
                              163, 255, 0;
                              161, 255, 0;
                              160, 255, 0;
                              158, 255, 0;
                              157, 255, 0;
                              155, 255, 0;
                              153, 255, 0;
                              152, 255, 0;
                              150, 255, 0;
                              149, 255, 0;
                              148, 255, 0;
                              146, 255, 0;
                              145, 255, 0;
                              143, 255, 0;
                              142, 255, 0;
                              140, 255, 0;
                              139, 255, 0;
                              137, 255, 0;
                              136, 255, 0;
                              134, 255, 0;
                              133, 255, 0;
                              131, 255, 0;
                              130, 255, 0;
                              128, 255, 0;
                              127, 255, 0;
                              126, 255, 0;
                              124, 255, 0;
                              123, 255, 0;
                              121, 255, 0;
                              120, 255, 0;
                              118, 255, 0;
                              117, 255, 0;
                              115, 255, 0;
                              114, 255, 0;
                              112, 255, 0;
                              111, 255, 0;
                              109, 255, 0;
                              108, 255, 0;
                              106, 255, 0;
                              105, 255, 0;
                              104, 255, 0;
                              102, 255, 0;
                              101, 255, 0;
                              99, 255, 0;
                              98, 255, 0;
                              96, 255, 0;
                              95, 255, 0;
                              93, 255, 0;
                              92, 255, 0;
                              90, 255, 0;
                              89, 255, 0;
                              87, 255, 0;
                              86, 255, 0;
                              84, 255, 0;
                              83, 255, 0;
                              82, 255, 0;
                              80, 255, 0;
                              79, 255, 0;
                              77, 255, 0;
                              76, 255, 0;
                              74, 255, 0;
                              73, 255, 0;
                              71, 255, 0;
                              70, 255, 0;
                              68, 255, 0;
                              67, 255, 0;
                              65, 255, 0;
                              64, 255, 0;
                              62, 255, 0;
                              61, 255, 0;
                              59, 255, 0]
    end

end
