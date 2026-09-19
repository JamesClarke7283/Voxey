class_name VillageContent
extends RefCounted

# Stable IDs; voxel storage supports these without reassigning older content.
const EMERALD_ORE = 512
const DEEP_EMERALD_ORE = 513
const EMERALD_BLOCK = 514
const BLAST_FURNACE = 515
const SMOKER = 516
const CARTOGRAPHY_TABLE = 517
const BREWING_STAND = 518
const COMPOSTER = 519
const BARREL = 520
const FLETCHING_TABLE = 521
const CAULDRON = 522
const LECTERN = 523
const STONECUTTER = 524
const LOOM = 525
const SMITHING_TABLE = 526
const GRINDSTONE = 527
const BELL = 528
const PATH = 529
const LANTERN = 530
# Mineclonia `mcl_lanterns:soul_lantern`: dimmer than an iron lantern, and lit by
# a soul torch. Voxey had the iron lantern but no soul variant.
const SOUL_LANTERN = 1168
# Mineclonia `mcl_bamboo`: a stalk that grows in segments and the item it drops.
const BAMBOO_ITEM = 1174
# Mineclonia `mcl_powder_snow`: a non-solid snow that freezes whoever is inside it,
# plus the bucket that carries it.
const POWDER_SNOW = 1175
const POWDER_SNOW_BUCKET = 1176
# Mineclonia `mcl_lush_caves`: the lit cave biome's vines and ground cover. The ids
# are written literally because `LushCaves` names `Nodes`, so referencing the module
# from this const block would close a cycle.
const GLOW_BERRY = 1179
const MOSS = 1204
const CAVE_VINES = 1177
const CAVE_VINES_LIT = 1178
# Mineclonia `mcl_lanterns:chain`: a thin metal column that blocks hang from.
const CHAIN = 1169
const CAMPFIRE = 531
const ANVIL = 532
const GRANITE = 533
const DIORITE = 534
const ANDESITE = 535
const POLISHED_GRANITE = 536
const POLISHED_DIORITE = 537
const POLISHED_ANDESITE = 538
const CHISELED_BRICKS = 539
const DRIPSTONE_BLOCK = 540
const QUARTZ_BLOCK = 541
const QUARTZ_PILLAR = 542
const GLASS_PANE = 543
const DRIED_KELP_BLOCK = 544
const ITEM_FRAME = 545
# Firework rockets, an elytra booster in the reference (mcl_fireworks).
const ROCKET_1 = 1244
const ROCKET_2 = 1245
const ROCKET_3 = 1246
# Heads (mcl_heads): the same item placed on the floor, a wall or a ceiling.
const HEAD_FLOOR = 1276
const HEAD_WALL = 1283
const HEAD_CEILING = 1290
# Scaffolding (mcl_bamboo): a climbable frame and its horizontal arm.
const SCAFFOLDING = 1300
const SCAFFOLDING_HORIZONTAL = 1301
const PAINTING = 546
const RED_CANDLE = 547
const YELLOW_CANDLE = 548
const WOODEN_DOOR = 549
const WOODEN_DOOR_OPEN = 550
const CARROTS_0 = 551
const CARROTS_1 = 552
const CARROTS_2 = 553
const CARROTS_3 = 554
const POTATOES_0 = 555
const POTATOES_1 = 556
const POTATOES_2 = 557
const POTATOES_3 = 558
const BEETROOTS_0 = 559
const BEETROOTS_1 = 560
const BEETROOTS_2 = 561
const BEETROOTS_3 = 562
const NETHER_WART_0 = 563
const NETHER_WART_1 = 564
const NETHER_WART_2 = 565
const NETHER_WART_3 = 566
const SWEET_BERRIES_0 = 567
const SWEET_BERRIES_1 = 568
const SWEET_BERRIES_2 = 569
const SWEET_BERRIES_3 = 570
const EMERALD = 768
const CARROT = 769
const POTATO = 770
const BAKED_POTATO = 771
const BEETROOT = 772
const BEETROOT_SEEDS = 773
const NETHER_WART_ITEM = 774
const SWEET_BERRY = 775
const GOLDEN_CARROT = 776
const GLISTERING_MELON = 777
const COOKIE = 778
const CAKE = 779
const SUSPICIOUS_STEW = 780
const BEETROOT_SOUP = 781
const RAW_COD = 782
const COOKED_COD = 783
const RAW_SALMON = 784
const COOKED_SALMON = 785
const TROPICAL_FISH = 786
const PUFFERFISH = 787
const COD_BUCKET = 788
const FISHING_ROD = 789
const CROSSBOW = 790
const ENCHANTED_BOOK = 791
const INK_SAC = 792
# Source `mcl_mobitems:glow_ink_sac`: a glow squid's drop. Voxey had no item for
# it, so the glow squid could not have existed.
const GLOW_INK_SAC = 861
# Mineclonia `mcl_nether:magma`, which burns whoever stands on it.
const MAGMA = 1158
# Ocean items: the nautilus shell is the fishing drop, the heart is new.
const NAUTILUS_SHELL = 1201
const HEART_OF_THE_SEA = 1310
# Conduit and its prismarine frame (mcl_conduits, mcl_ocean).
const CONDUIT = 1311
const PRISMARINE = 1312
const PRISMARINE_BRICK = 1313
const PRISMARINE_DARK = 1314
const SEA_LANTERN = 1315
const PRISMARINE_SHARD = 1316
const PRISMARINE_CRYSTALS = 1317
# Coral (mcl_ocean/corals.lua): five species, six forms each, grouped in fives.
const CORAL_FIRST = 1330
# Sea pickles (mcl_ocean/sea_pickle.lua): four sizes, lit then unlit.
const PICKLE_FIRST = 1360
# Seagrass (mcl_ocean/seagrass.lua): one item and one node per supported surface.
const SEAGRASS = 1368
const SEAGRASS_FIRST = 1369
# Banner pattern items (mcl_banners/items.lua): the ten special patterns.
const PATTERN_FIRST = 1380
# Beacon (mcl_beacons): the block, its beam, and the nether star it needs.
const BEACON = 1390
const BEACON_BEAM = 1391
const NETHER_STAR = 1392
# Totem of Undying (mcl_totems): a one-use lethal-damage save.
const TOTEM = 1395
# The pyramid accepts these, which the source marks with `beacon_block`.
const NETHERITE_BLOCK = 694
const PATTERN_KEYS = ["thing","skull","creeper","flower","bricks","curly_border","globe","piglin","guster","flow"]
# Six forms per species: block, dead block, plant, dead plant, fan, dead fan.
const CORAL_STRIDE = 6
const RAW_BEEF = 793
const COOKED_BEEF = 794
const RAW_PORKCHOP = 795
const COOKED_PORKCHOP = 796
const RAW_CHICKEN = 797
const COOKED_CHICKEN = 798
const RAW_MUTTON = 799
const COOKED_MUTTON = 800
const RAW_RABBIT = 801
const COOKED_RABBIT = 802
const RABBIT_STEW = 803
const RABBIT_HIDE = 804
const RABBIT_FOOT = 805
const LEATHER_HORSE_ARMOR = 806
const GLASS_BOTTLE = 807
const WATER_BOTTLE = 808
const XP_BOTTLE = 809
const EMPTY_MAP = 810
const FILLED_MAP = 811
const GLOBE_PATTERN = 812
const SHIELD = 813
const KELP = 814
const DRIED_KELP = 815
const COCOA_BEANS = 816
const CHAIN_HELMET = 817
const CHAIN_CHESTPLATE = 818
const CHAIN_LEGGINGS = 819
const CHAIN_BOOTS = 820
const WOOL_WHITE = 571
const WOOL_GREY = 572
const WOOL_SILVER = 573
const WOOL_BLACK = 574
const WOOL_YELLOW = 575
const WOOL_ORANGE = 576
const WOOL_RED = 577
const WOOL_MAGENTA = 578
const WOOL_PURPLE = 579
const WOOL_BLUE = 580
const WOOL_CYAN = 581
const WOOL_LIME = 582
const WOOL_GREEN = 583
const WOOL_PINK = 584
const WOOL_LIGHT_BLUE = 585
const WOOL_BROWN = 586
const CARPET_WHITE = 587
const CARPET_GREY = 588
const CARPET_SILVER = 589
const CARPET_BLACK = 590
const CARPET_YELLOW = 591
const CARPET_ORANGE = 592
const CARPET_RED = 593
const CARPET_MAGENTA = 594
const CARPET_PURPLE = 595
const CARPET_BLUE = 596
const CARPET_CYAN = 597
const CARPET_LIME = 598
const CARPET_GREEN = 599
const CARPET_PINK = 600
const CARPET_LIGHT_BLUE = 601
const CARPET_BROWN = 602
const TERRACOTTA_WHITE = 603
const TERRACOTTA_GREY = 604
const TERRACOTTA_SILVER = 605
const TERRACOTTA_BLACK = 606
const TERRACOTTA_YELLOW = 607
const TERRACOTTA_ORANGE = 608
const TERRACOTTA_RED = 609
const TERRACOTTA_MAGENTA = 610
const TERRACOTTA_PURPLE = 611
const TERRACOTTA_BLUE = 612
const TERRACOTTA_CYAN = 613
const TERRACOTTA_LIME = 614
const TERRACOTTA_GREEN = 615
const TERRACOTTA_PINK = 616
const TERRACOTTA_LIGHT_BLUE = 617
const TERRACOTTA_BROWN = 618
const GLAZED_WHITE = 619
const GLAZED_GREY = 620
const GLAZED_SILVER = 621
const GLAZED_BLACK = 622
const GLAZED_YELLOW = 623
const GLAZED_ORANGE = 624
const GLAZED_RED = 625
const GLAZED_MAGENTA = 626
const GLAZED_PURPLE = 627
const GLAZED_BLUE = 628
const GLAZED_CYAN = 629
const GLAZED_LIME = 630
const GLAZED_GREEN = 631
const GLAZED_PINK = 632
const GLAZED_LIGHT_BLUE = 633
const GLAZED_BROWN = 634
const BANNER_FIRST = 635
# The sixteen banners run in this order, matching the source's colour order.
const BANNER_IDS = [635,636,637,638,639,640,641,642,643,644,645,646,647,648,649,650]
const BANNER_WHITE = 635
const BANNER_GREY = 636
const BANNER_SILVER = 637
const BANNER_BLACK = 638
const BANNER_YELLOW = 639
const BANNER_ORANGE = 640
const BANNER_RED = 641
const BANNER_MAGENTA = 642
const BANNER_PURPLE = 643
const BANNER_BLUE = 644
const BANNER_CYAN = 645
const BANNER_LIME = 646
const BANNER_GREEN = 647
const BANNER_PINK = 648
const BANNER_LIGHT_BLUE = 649
const BANNER_BROWN = 650
const BED_WHITE = 651
const BED_GREY = 652
const BED_SILVER = 653
const BED_BLACK = 654
const BED_YELLOW = 655
const BED_ORANGE = 656
const BED_RED = 657
const BED_MAGENTA = 658
const BED_PURPLE = 659
const BED_BLUE = 660
const BED_CYAN = 661
const BED_LIME = 662
const BED_GREEN = 663
const BED_PINK = 664
const BED_LIGHT_BLUE = 665
const BED_BROWN = 666
const BED_HEAD_WHITE = 667
const BED_HEAD_GREY = 668
const BED_HEAD_SILVER = 669
const BED_HEAD_BLACK = 670
const BED_HEAD_YELLOW = 671
const BED_HEAD_ORANGE = 672
const BED_HEAD_RED = 673
const BED_HEAD_MAGENTA = 674
const BED_HEAD_PURPLE = 675
const BED_HEAD_BLUE = 676
const BED_HEAD_CYAN = 677
const BED_HEAD_LIME = 678
const BED_HEAD_GREEN = 679
const BED_HEAD_PINK = 680
const BED_HEAD_LIGHT_BLUE = 681
const BED_HEAD_BROWN = 682
const DYE_WHITE = 821
const DYE_GREY = 822
const DYE_SILVER = 823
const DYE_BLACK = 824
const DYE_YELLOW = 825
const DYE_ORANGE = 826
const DYE_RED = 827
const DYE_MAGENTA = 828
const DYE_PURPLE = 829
const DYE_BLUE = 830
const DYE_CYAN = 831
const DYE_LIME = 832
const DYE_GREEN = 833
const DYE_PINK = 834
const DYE_LIGHT_BLUE = 835
const DYE_BROWN = 836
const BOAT_OAK = 837
const BOAT_ACACIA = 838
const BOAT_SPRUCE = 839
const BOAT_DARK_OAK = 840
const BOAT_BIRCH = 841
const HEALING_ARROW = 842
const HARMING_ARROW = 843
const NIGHT_VISION_ARROW = 844
const SWIFTNESS_ARROW = 845
const SLOWNESS_ARROW = 846
const LEAPING_ARROW = 847
const POISON_ARROW = 848
const REGENERATION_ARROW = 849
const STRENGTH_ARROW = 850
const WEAKNESS_ARROW = 851
const INVISIBILITY_ARROW = 852
const WATER_BREATHING_ARROW = 853
const FIRE_RESISTANCE_ARROW = 854
const HEALING_POTION = 855
const SWIFTNESS_POTION = 856
const FIRE_RESISTANCE_POTION = 857
const STRENGTH_POTION = 858
const NIGHT_VISION_POTION = 859
const WATER_BREATHING_POTION = 860
const MUD = 683
const LILY_PAD = 684
const SWAMP_GRASS = 685
const KELP_PLANT = 686
const COCOA_POD = 687
const RIPE_COCOA_POD = 688
const LEAD = 930
const SPIDER_EYE = 950
const FERMENTED_SPIDER_EYE = 940
const GLOWSTONE_DUST = 941
const DRAGON_BREATH = 942
const PHANTOM_MEMBRANE = 943
const BREEZE_ROD = 944
const TURTLE_SCUTE = 945
const TRIDENT = 946
const MACE = 947
const HEAVY_CORE = 948
const TURTLE_HELMET = 949
const SLIME_BLOCK = 689
const COBWEB = 690
const FROSTED_ICE = 691
const RECOVERY_CHEST = 692
const BLOCKS = [
	512,513,514,515,516,517,518,519,520,521,522,523,524,525,526,527,528,529,530,531,532,533,534,535,536,537,538,539,540,541,542,543,544,545,546,547,548,549,550,551,552,553,554,555,556,557,558,559,560,561,562,563,564,565,566,567,568,569,570,571,572,573,574,575,576,577,578,579,580,581,582,583,584,585,586,587,588,589,590,591,592,593,594,595,596,597,598,599,600,601,602,603,604,605,606,607,608,609,610,611,612,613,614,615,616,617,618,619,620,621,622,623,624,625,626,627,628,629,630,631,632,633,634,635,636,637,638,639,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,657,658,659,660,661,662,663,664,665,666,667,668,669,670,671,672,673,674,675,676,677,678,679,680,681,682,683,684,685,686,687,688,689,690,691,692,693,694,695,696,697,1241,1242,1243,5610,5611,5612,6700,6800,7400,7401,7402,7403,7404,7405,7300,45,7510,7511,7512,7513,7514,7515,7516,7517,7518,7519,7520,7521,7530,7531,7532,7533,7534,7535,7536,7537,7538,7539,7540,7541,7551,7552,7553,7560,7561,7562,7563,7700,7701,7702,7703,7704,7708,7716,7724,7732,7600,7601,7602,7603,7604,7605,7606,7607,7608,7609,7610,7611,7612,7613,7614,7615,7616,7617,7618,7619,7620,7621,7622,7623,7624,7625,7626,7627,7628,7629,7630,7631,7632,7633,7634,7635,7636,7637,7638,7639,7640,7641,7642,7643,7644,7645,7646,7647,7652,7653,7660,7661,7662,7663,7664,7665,7666,7667,7668,9500,9501,9502,9510,9511,9512,9513,9520,9521,9522,9523,9530,9531,9532,9533,9540,9541,9542,9543,9544,9545,9546,9547,9550,9551,9552,9553,9554,9555,9556,9557,9400,9401,9402,9901,9902,9903,10800,10801,9300,9320,9321,9322,9323,9324,9325,1300,1301,1311,1312,1313,1314,1315,1390,1391,1276,1277,1278,1279,1280,1281,1282,1283,1284,1285,1286,1287,1288,1289,1290,1291,1292,1293,1294,1295,1296,8000,22,8010,8011,8012,8013,8014,8015,29,8020,8021,8022,8023,8030,8031,8032,8033,1330,1331,1332,1333,1334,1335,1336,1337,1338,1339,1340,1341,1342,1343,1344,1345,1346,1347,1348,1349,1350,1351,1352,1353,1354,1355,1356,1357,1358,1359,1360,1361,1362,1363,1364,1365,1366,1367,1369,1370,1371,1372,1373,1374,1168,1169,1100,1101,1102,1103,1104,1105,1117,1118,1150,1151,1152,1153,1154,1155,1156,1157,1158,1159,1160,1161,1162,1163,1164,1165,1166,1167,1247,1170,1171,1172,1173,1174,1207,1208,1209,1210,1211,1212,1175,1177,1178,1180,1181,1182,1183,1184,1185,1186,1187,1188,1189,1190,1191,1192,1193,1194,1195,1196,1204,1205,1206,1220,1221,1222,1223,1240,5613,1213,1214,1215,1216,1217,11072,11073,11074,11075,11076,11077,11078,11079,11080,11081,11082,11083,11084,11085,11086,11087,11088,11089,11090,11091,11092,11093,11094,11095,11096,11097,11098,11099,11100,11101,11102,11103,11104,11105,11106,11107,11108,11109,11110,11111,11112,11113,11114,11115,11116,11117,11118,11119,11120,11121,11122,11123,11124,11125,11126,11127,11128,11129,11130,11131,11132,11133,11134,11135,11136,11137,11138,11139,11140,11141,11142,11143,11144,11145,11146,11147,11148,11149,11150,11151,11152,11153,11154,11155,11156,11157,11158,11159,11160,11161,11162,11163,11164,11165,11166,11167,11168,11169,11170,11171,11172,11173,11174,11175,11176,11177,11178,11179,11180,11181,11182,11183,11184,11185,11186,11187,11188,11189,11190,11191,11192,11193,11194,11195,11196,11197,11198,11199,11280,11281,11200,11201,11202,11203,11204,11205,11206,11207,11208,11209,11210,11211,11212,11213,11214,11215,11216,11217,11218,11219,11220,11221,11222,11223,11224,11225,11226,11227,11228,11229,11230,11231,11232,11233,11234,11235,11236,11237,11238,11239,11240,11241,11440,11441,11442,11444,11445,
	11446,11447,
	11511,11512,11513,11514,11515,11516,11517,11518,
	11521,11522,11523,11524,11525,11526,11527,11528,11529,
	11530,11531,11532,11533,11534,11535,11536,11537,11538,11539,11540,11541,11542,11543,11544,11545,
	11546,
	11470,11471,11472,11473,11474,11475,11476,11477,11478,11479,11480,11481,11400,11401,11402,11403,11404,11405,11406,11407,11408,11409,11410,11411,11412,11413,11414,11415,11416,11417,11303,11304,11305,11507,11508,11509,11040,11041,11042,11043,11044,11045,11046,11047,11048,11049,11050,11051,11052,11053,11054,11055,11056,11057,11058,11059,11060,11061,11062,11063,11064,11065,11066,11067,11068,11069,11070,11071,
]
const DATA = {
	9300:Rails.DATA[9300],
	9320:Rails.DATA[9320],
	9321:Rails.DATA[9321],
	9322:Rails.DATA[9322],
	9323:Rails.DATA[9323],
	9324:Rails.DATA[9324],
	9325:Rails.DATA[9325],
	861:{"name":"Glow ink sac","color":"5ce8de","glint":true},
	Magma.ID:Magma.DATA[Magma.ID],
	1177:{"name":"Cave vines","block":true,"shape":"vine","color":"5d8b3c","hardness":0.0,"tool":2,"plant":true},
	1178:{"name":"Lit cave vines","block":true,"shape":"vine","color":"7fae4a","hardness":0.0,"tool":2,"plant":true,"light":14,"emits":14},
	1179:{"name":"Glow berry","color":"e8b34a","food":2},
	1204:{"name":"Moss block","block":true,"color":"5a7a3c","hardness":0.5,"tool":2},
	1205:{"name":"Moss carpet","block":true,"shape":"carpet","color":"5a7a3c","hardness":0.1,"tool":2},
	1206:{"name":"Hanging roots","block":true,"shape":"plant","color":"6b5636","hardness":0.0,"tool":2,"plant":true},
	1207:HugeMushrooms.BLOCK_DATA[1207],
	1208:HugeMushrooms.BLOCK_DATA[1208],
	1209:HugeMushrooms.BLOCK_DATA[1209],
	1210:HugeMushrooms.BLOCK_DATA[1210],
	1211:HugeMushrooms.BLOCK_DATA[1211],
	1212:HugeMushrooms.BLOCK_DATA[1212],
	1213:RespawnAnchors.BLOCK_DATA[1213],
	1214:RespawnAnchors.BLOCK_DATA[1214],
	1215:RespawnAnchors.BLOCK_DATA[1215],
	1216:RespawnAnchors.BLOCK_DATA[1216],
	1217:RespawnAnchors.BLOCK_DATA[1217],
	1175:{"name":"Powder snow","block":true,"shape":"cube","color":"f7fbfc","hardness":0.25,"tool":2},
	1176:{"name":"Bucket of powder snow","color":"c9ced6","stack":1},
	1170:{"name":"Bamboo shoot","block":true,"shape":"bamboo","color":"7ea33c","hardness":1.0,"tool":0,"plant":true},
	1171:{"name":"Bamboo","block":true,"shape":"bamboo","color":"8fb04a","hardness":1.0,"tool":0,"plant":true},
	1172:{"name":"Bamboo","block":true,"shape":"bamboo","color":"8fb04a","hardness":1.0,"tool":0,"plant":true,"hidden":true},
	1173:{"name":"Bamboo","block":true,"shape":"bamboo","color":"9abd52","hardness":1.0,"tool":0,"plant":true,"hidden":true},
	1174:{"name":"Bamboo","color":"8fb04a","stack":64},
	1168:{"name":"Soul lantern","block":true,"shape":"lantern","color":"4d7a72","hardness":3.5,"light":10,"emits":10},
	1169:{"name":"Chain","block":true,"shape":"chain","color":"8a8a92","hardness":5.0,"tool":0},
	1162:MonsterEggs.DATA[1162],
	1163:MonsterEggs.DATA[1163],
	1164:MonsterEggs.DATA[1164],
	1165:MonsterEggs.DATA[1165],
	1166:MonsterEggs.DATA[1166],
	1167:MonsterEggs.DATA[1167],
	1247:{"name":"Trapped chest","block":true,"color":"a2622f","hardness":2.5,"tool":0,"chest":true},
	9900:Archaeology.DATA[9900],
	9901:Archaeology.DATA[9901],
	9902:Archaeology.DATA[9902],
	9903:Archaeology.DATA[9903],
	9910:Archaeology.DATA[9910],
	9911:Archaeology.DATA[9911],
	9912:Archaeology.DATA[9912],
	9913:Archaeology.DATA[9913],
	10800:{"name":"Flower pot","block":true,"shape":"pot","color":"a5673f","hardness":0.6},
	10801:{"name":"Armor stand","block":true,"shape":"stand","color":"b28c52","hardness":0.6},
	9400:Sponges.DATA[9400],
	9401:Sponges.DATA[9401],
	9402:Sponges.DATA[9402],
	8000:Farmland.DATA[8000],
	8070:CropFarming.DATA[8070],
	8033:CropFarming.DATA[8033],
	8032:CropFarming.DATA[8032],
	8031:CropFarming.DATA[8031],
	8030:CropFarming.DATA[8030],
	8023:CropFarming.DATA[8023],
	8022:CropFarming.DATA[8022],
	8021:CropFarming.DATA[8021],
	8020:CropFarming.DATA[8020],
	29:CropFarming.DATA[29],
	8015:CropFarming.DATA[8015],
	8014:CropFarming.DATA[8014],
	8013:CropFarming.DATA[8013],
	8012:CropFarming.DATA[8012],
	8011:CropFarming.DATA[8011],
	8010:CropFarming.DATA[8010],
	22:CropFarming.DATA[22],
	7600:Beehives.DATA[7600],
	7601:Beehives.DATA[7601],
	7602:Beehives.DATA[7602],
	7603:Beehives.DATA[7603],
	7604:Beehives.DATA[7604],
	7605:Beehives.DATA[7605],
	7606:Beehives.DATA[7606],
	7607:Beehives.DATA[7607],
	7608:Beehives.DATA[7608],
	7609:Beehives.DATA[7609],
	7610:Beehives.DATA[7610],
	7611:Beehives.DATA[7611],
	7612:Beehives.DATA[7612],
	7613:Beehives.DATA[7613],
	7614:Beehives.DATA[7614],
	7615:Beehives.DATA[7615],
	7616:Beehives.DATA[7616],
	7617:Beehives.DATA[7617],
	7618:Beehives.DATA[7618],
	7619:Beehives.DATA[7619],
	7620:Beehives.DATA[7620],
	7621:Beehives.DATA[7621],
	7622:Beehives.DATA[7622],
	7623:Beehives.DATA[7623],
	7624:Beehives.DATA[7624],
	7625:Beehives.DATA[7625],
	7626:Beehives.DATA[7626],
	7627:Beehives.DATA[7627],
	7628:Beehives.DATA[7628],
	7629:Beehives.DATA[7629],
	7630:Beehives.DATA[7630],
	7631:Beehives.DATA[7631],
	7632:Beehives.DATA[7632],
	7633:Beehives.DATA[7633],
	7634:Beehives.DATA[7634],
	7635:Beehives.DATA[7635],
	7636:Beehives.DATA[7636],
	7637:Beehives.DATA[7637],
	7638:Beehives.DATA[7638],
	7639:Beehives.DATA[7639],
	7640:Beehives.DATA[7640],
	7641:Beehives.DATA[7641],
	7642:Beehives.DATA[7642],
	7643:Beehives.DATA[7643],
	7644:Beehives.DATA[7644],
	7645:Beehives.DATA[7645],
	7646:Beehives.DATA[7646],
	7647:Beehives.DATA[7647],
	7650:Beehives.DATA[7650],
	7651:Beehives.DATA[7651],
	7652:Beehives.DATA[7652],
	7653:Beehives.DATA[7653],
	7660:Beehives.DATA[7660],
	7661:Beehives.DATA[7661],
	7662:Beehives.DATA[7662],
	7663:Beehives.DATA[7663],
	7664:Beehives.DATA[7664],
	7665:Beehives.DATA[7665],
	7666:Beehives.DATA[7666],
	7667:Beehives.DATA[7667],
	7668:Beehives.DATA[7668],
	7700:Amethyst.DATA[7700],
	7701:Amethyst.DATA[7701],
	7702:Amethyst.DATA[7702],
	7703:Amethyst.DATA[7703],
	7704:Amethyst.DATA[7704],
	7705:Amethyst.DATA[7705],
	7708:Amethyst.DATA[7708],
	7709:Amethyst.DATA[7709],
	7710:Amethyst.DATA[7710],
	7711:Amethyst.DATA[7711],
	7712:Amethyst.DATA[7712],
	7713:Amethyst.DATA[7713],
	7716:Amethyst.DATA[7716],
	7717:Amethyst.DATA[7717],
	7718:Amethyst.DATA[7718],
	7719:Amethyst.DATA[7719],
	7720:Amethyst.DATA[7720],
	7721:Amethyst.DATA[7721],
	7724:Amethyst.DATA[7724],
	7725:Amethyst.DATA[7725],
	7726:Amethyst.DATA[7726],
	7727:Amethyst.DATA[7727],
	7728:Amethyst.DATA[7728],
	7729:Amethyst.DATA[7729],
	7732:Amethyst.DATA[7732],
	7733:Amethyst.DATA[7733],
	7734:Amethyst.DATA[7734],
	7735:Amethyst.DATA[7735],
	7736:Amethyst.DATA[7736],
	7737:Amethyst.DATA[7737],
	7500:FruitCrops.DATA[7500],
	7501:FruitCrops.DATA[7501],
	45:FruitCrops.DATA[45],
	7510:FruitCrops.DATA[7510],
	7511:FruitCrops.DATA[7511],
	7512:FruitCrops.DATA[7512],
	7513:FruitCrops.DATA[7513],
	7514:FruitCrops.DATA[7514],
	7515:FruitCrops.DATA[7515],
	7516:FruitCrops.DATA[7516],
	7517:FruitCrops.DATA[7517],
	7518:FruitCrops.DATA[7518],
	7519:FruitCrops.DATA[7519],
	7520:FruitCrops.DATA[7520],
	7521:FruitCrops.DATA[7521],
	7530:FruitCrops.DATA[7530],
	7531:FruitCrops.DATA[7531],
	7532:FruitCrops.DATA[7532],
	7533:FruitCrops.DATA[7533],
	7534:FruitCrops.DATA[7534],
	7535:FruitCrops.DATA[7535],
	7536:FruitCrops.DATA[7536],
	7537:FruitCrops.DATA[7537],
	7538:FruitCrops.DATA[7538],
	7539:FruitCrops.DATA[7539],
	7540:FruitCrops.DATA[7540],
	7541:FruitCrops.DATA[7541],
	7551:FruitCrops.DATA[7551],
	7552:FruitCrops.DATA[7552],
	7553:FruitCrops.DATA[7553],
	7560:FruitCrops.DATA[7560],
	7561:FruitCrops.DATA[7561],
	7562:FruitCrops.DATA[7562],
	7563:FruitCrops.DATA[7563],
	7300:Dungeons.DATA[7300],
	7890:Spyglass.DATA[7890],
	7400:DenseMaterials.DATA[7400],
	7401:DenseMaterials.DATA[7401],
	7402:DenseMaterials.DATA[7402],
	7403:DenseMaterials.DATA[7403],
	7404:DenseMaterials.DATA[7404],
	7405:DenseMaterials.DATA[7405],
	6800:Jukeboxes.DATA[6800],
	6810:Jukeboxes.DATA[6810],
	6811:Jukeboxes.DATA[6811],
	6812:Jukeboxes.DATA[6812],
	6813:Jukeboxes.DATA[6813],
	6814:Jukeboxes.DATA[6814],
	6815:Jukeboxes.DATA[6815],
	6816:Jukeboxes.DATA[6816],
	6700:NoteBlocks.DATA[6700],
	5610:{"name":"Poppy","block":true,"shape":"plant","color":"d84b4b","hardness":0.0,"flammable":true,"compostability":65},
	5611:{"name":"Dandelion","block":true,"shape":"plant","color":"efc642","hardness":0.0,"flammable":true,"compostability":65},
	5612:{"name":"Oxeye daisy","block":true,"shape":"plant","color":"eee5d2","hardness":0.0,"flammable":true,"compostability":65},
	5613:{"name":"Tall grass","block":true,"shape":"plant","color":"6fa03c","hardness":0.0,"flammable":true,"compostability":30},
	1250:Boats.DATA[1250],
	1260:Boats.DATA[1260],
	1261:Boats.DATA[1261],
	1251:Boats.DATA[1251],
	1252:Boats.DATA[1252],
	1253:Boats.DATA[1253],
	1254:Boats.DATA[1254],
	1240:{"name":"Daylight detector","color":"d9c598","block":true,"hardness":0.2,"tool":1,"drop":1240},
	1241:{"name":"Inverted daylight detector","color":"6b819d","block":true,"hardness":0.2,"tool":1,"drop":1240,"hidden":true},
	1242:{"name":"Target","color":"cebc87","block":true,"hardness":0.5,"tool":4,"drop":1242},
	1243:{"name":"Target (powered)","color":"d2b88a","block":true,"hardness":0.5,"tool":4,"drop":1242,"hidden":true},
	1180:{"name":"Ender chest","color":"243d39","block":true,"hardness":22.5,"blast_resistance":3000,"tool":0,"family":"ender_chest"},
	1181:{"name":"White shulker box","color":"e4e4d7","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1182:{"name":"Grey shulker box","color":"626c70","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1183:{"name":"Light grey shulker box","color":"b0b4ac","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1184:{"name":"Black shulker box","color":"333740","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1185:{"name":"Yellow shulker box","color":"edc647","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1186:{"name":"Orange shulker box","color":"e4943e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1187:{"name":"Red shulker box","color":"b83d41","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1188:{"name":"Magenta shulker box","color":"b94baf","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1189:{"name":"Purple shulker box","color":"824aaa","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1190:{"name":"Blue shulker box","color":"4966ad","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1191:{"name":"Cyan shulker box","color":"378a99","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1192:{"name":"Lime shulker box","color":"8bbe45","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1193:{"name":"Green shulker box","color":"51763e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1194:{"name":"Pink shulker box","color":"dd8eac","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1195:{"name":"Light blue shulker box","color":"79b4d2","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1196:{"name":"Brown shulker box","color":"79563e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1150:{"name":"Deepslate tiles","color":"45464c","block":true,"hardness":3.5,"blast_resistance":6,"smelt":1152},
	1151:{"name":"Cracked deepslate bricks","color":"484950","block":true,"hardness":3.5,"blast_resistance":6},
	1152:{"name":"Cracked deepslate tiles","color":"43444a","block":true,"hardness":3.5,"blast_resistance":6},
	1153:{"name":"Chiseled deepslate","color":"494a50","block":true,"hardness":3.5,"blast_resistance":6},
	1154:{"name":"Polished tuff","color":"7a7e72","block":true,"hardness":1.5,"blast_resistance":6},
	1155:{"name":"Tuff bricks","color":"74796c","block":true,"hardness":1.5,"blast_resistance":6},
	1156:{"name":"Chiseled tuff","color":"777c6f","block":true,"hardness":1.5,"blast_resistance":6},
	1157:{"name":"Chiseled tuff bricks","color":"71786a","block":true,"hardness":1.5,"blast_resistance":6},
	# Mineclonia `mcl_core:stonebrickcarved`, `stonebrickcracked` and
	# `stonebrickmossy`. The plain bricks are id 20; cracked bricks come out of a
	# furnace, which is the source's `_mcl_cooking_output`.
	1159:{"name":"Chiseled stone bricks","color":"7a7a76","block":true,"hardness":1.5,"blast_resistance":6},
	1160:{"name":"Cracked stone bricks","color":"787874","block":true,"hardness":1.5,"blast_resistance":6},
	1161:{"name":"Mossy stone bricks","color":"6d7a63","block":true,"hardness":1.5,"blast_resistance":6},
	1119:{"name":"Wall torch","color":"c69349","block":true,"shape":"wall_torch","hidden":true,"hardness":0.22},
	1120:{"name":"Wall torch","color":"c69349","block":true,"shape":"wall_torch","hidden":true,"hardness":0.22},
	1121:{"name":"Wall torch","color":"c69349","block":true,"shape":"wall_torch","hidden":true,"hardness":0.22},
	1122:{"name":"Wall torch","color":"c69349","block":true,"shape":"wall_torch","hidden":true,"hardness":0.22},
	1117:{"name":"Fire","color":"ec8e33","block":true,"shape":"plant","hardness":0},
	1118:{"name":"Eternal fire","color":"ec8e33","block":true,"shape":"plant","hardness":0},
	1116:{"name":"Fire charge","color":"ec8137","family":"fire_charge"},
	1244:{"name":"Firework rocket","color":"f2f2f2","stack":64,"fuel":0},
	1245:{"name":"Firework rocket","color":"f2f2f2","stack":64,"fuel":0},
	1246:{"name":"Firework rocket","color":"f2f2f2","stack":64,"fuel":0},
	1276:{"name":"Head","block":true,"shape":"head","color":"4f7a3f","hardness":1.0,"stack":64},
	1277:{"name":"Head","block":true,"shape":"head","color":"4fae4f","hardness":1.0,"stack":64},
	1278:{"name":"Head","block":true,"shape":"head","color":"b58a62","hardness":1.0,"stack":64},
	1279:{"name":"Head","block":true,"shape":"head","color":"c9c9c9","hardness":1.0,"stack":64},
	1280:{"name":"Head","block":true,"shape":"head","color":"3b3b3b","hardness":1.0,"stack":64},
	1281:{"name":"Head","block":true,"shape":"head","color":"e2a0a0","hardness":1.0,"stack":64},
	1282:{"name":"Head","block":true,"shape":"head","color":"5b6f57","hardness":1.0,"stack":64},
	1283:{"name":"Head","block":true,"shape":"head","color":"4f7a3f","hardness":1.0,"stack":64,"hidden":true,"drop":1276},
	1284:{"name":"Head","block":true,"shape":"head","color":"4fae4f","hardness":1.0,"stack":64,"hidden":true,"drop":1277},
	1285:{"name":"Head","block":true,"shape":"head","color":"b58a62","hardness":1.0,"stack":64,"hidden":true,"drop":1278},
	1286:{"name":"Head","block":true,"shape":"head","color":"c9c9c9","hardness":1.0,"stack":64,"hidden":true,"drop":1279},
	1287:{"name":"Head","block":true,"shape":"head","color":"3b3b3b","hardness":1.0,"stack":64,"hidden":true,"drop":1280},
	1288:{"name":"Head","block":true,"shape":"head","color":"e2a0a0","hardness":1.0,"stack":64,"hidden":true,"drop":1281},
	1289:{"name":"Head","block":true,"shape":"head","color":"5b6f57","hardness":1.0,"stack":64,"hidden":true,"drop":1282},
	1290:{"name":"Head","block":true,"shape":"head","color":"4f7a3f","hardness":1.0,"stack":64,"hidden":true,"drop":1276},
	1300:{"name":"Scaffolding","block":true,"shape":"scaffolding","color":"c8b06a","hardness":0.0,"stack":64,"flammable":true},
	1301:{"name":"Scaffolding","block":true,"shape":"scaffolding","color":"c8b06a","hardness":0.0,"stack":64,"hidden":true,"drop":1300},
	1310:{"name":"Heart of the sea","color":"4fd0c0","stack":64},
	1311:{"name":"Conduit","block":true,"color":"2f6f66","hardness":3.0,"tool":0,"light":15},
	1312:{"name":"Prismarine","block":true,"color":"63a89c","hardness":1.5,"tool":0,"blast_resistance":6},
	1313:{"name":"Prismarine bricks","block":true,"color":"4f8f88","hardness":1.5,"tool":0,"blast_resistance":6},
	1314:{"name":"Dark prismarine","block":true,"color":"1f4f47","hardness":1.5,"tool":0,"blast_resistance":6},
	1315:{"name":"Sea lantern","block":true,"color":"b8e6dc","hardness":0.3,"tool":0,"light":15},
	1316:{"name":"Prismarine shard","color":"4f8f88","stack":64},
	1317:{"name":"Prismarine crystals","color":"7fd8c8","stack":64},
	1330:{"name":"Tube Coral Block","block":true,"color":"5c7fb8","hardness":1.5,"tool":0,"drop":1331},
	1331:{"name":"Dead Tube Coral Block","block":true,"color":"9a9288","hardness":1.5,"tool":0,"hidden":true},
	1332:{"name":"Tube Coral","block":true,"shape":"plant","color":"5c7fb8","hardness":0.0,"drop":1333},
	1333:{"name":"Dead Tube Coral","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1334:{"name":"Tube Coral Fan","block":true,"shape":"plant","color":"5c7fb8","hardness":0.0,"drop":1335},
	1335:{"name":"Dead Tube Coral Fan","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1336:{"name":"Brain Coral Block","block":true,"color":"c86bb0","hardness":1.5,"tool":0,"drop":1337},
	1337:{"name":"Dead Brain Coral Block","block":true,"color":"9a9288","hardness":1.5,"tool":0,"hidden":true},
	1338:{"name":"Brain Coral","block":true,"shape":"plant","color":"c86bb0","hardness":0.0,"drop":1339},
	1339:{"name":"Dead Brain Coral","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1340:{"name":"Brain Coral Fan","block":true,"shape":"plant","color":"c86bb0","hardness":0.0,"drop":1341},
	1341:{"name":"Dead Brain Coral Fan","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1342:{"name":"Bubble Coral Block","block":true,"color":"9d5ad0","hardness":1.5,"tool":0,"drop":1343},
	1343:{"name":"Dead Bubble Coral Block","block":true,"color":"9a9288","hardness":1.5,"tool":0,"hidden":true},
	1344:{"name":"Bubble Coral","block":true,"shape":"plant","color":"9d5ad0","hardness":0.0,"drop":1345},
	1345:{"name":"Dead Bubble Coral","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1346:{"name":"Bubble Coral Fan","block":true,"shape":"plant","color":"9d5ad0","hardness":0.0,"drop":1347},
	1347:{"name":"Dead Bubble Coral Fan","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1348:{"name":"Fire Coral Block","block":true,"color":"d4674f","hardness":1.5,"tool":0,"drop":1349},
	1349:{"name":"Dead Fire Coral Block","block":true,"color":"9a9288","hardness":1.5,"tool":0,"hidden":true},
	1350:{"name":"Fire Coral","block":true,"shape":"plant","color":"d4674f","hardness":0.0,"drop":1351},
	1351:{"name":"Dead Fire Coral","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1352:{"name":"Fire Coral Fan","block":true,"shape":"plant","color":"d4674f","hardness":0.0,"drop":1353},
	1353:{"name":"Dead Fire Coral Fan","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1354:{"name":"Horn Coral Block","block":true,"color":"c9a24f","hardness":1.5,"tool":0,"drop":1355},
	1355:{"name":"Dead Horn Coral Block","block":true,"color":"9a9288","hardness":1.5,"tool":0,"hidden":true},
	1356:{"name":"Horn Coral","block":true,"shape":"plant","color":"c9a24f","hardness":0.0,"drop":1357},
	1357:{"name":"Dead Horn Coral","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1358:{"name":"Horn Coral Fan","block":true,"shape":"plant","color":"c9a24f","hardness":0.0,"drop":1359},
	1359:{"name":"Dead Horn Coral Fan","block":true,"shape":"plant","color":"9a9288","hardness":0.0,"hidden":true},
	1360:{"name":"Sea pickle","block":true,"shape":"plant","color":"7fd06a","hardness":0.0,"light":6,"stack":64},
	1361:{"name":"Sea pickle","block":true,"shape":"plant","color":"7fd06a","hardness":0.0,"light":9,"stack":64},
	1362:{"name":"Sea pickle","block":true,"shape":"plant","color":"7fd06a","hardness":0.0,"light":12,"stack":64},
	1363:{"name":"Sea pickle","block":true,"shape":"plant","color":"7fd06a","hardness":0.0,"light":15,"stack":64},
	1364:{"name":"Sea pickle","block":true,"shape":"plant","color":"4f7a44","hardness":0.0,"hidden":true,"stack":64},
	1365:{"name":"Sea pickle","block":true,"shape":"plant","color":"4f7a44","hardness":0.0,"hidden":true,"stack":64},
	1366:{"name":"Sea pickle","block":true,"shape":"plant","color":"4f7a44","hardness":0.0,"hidden":true,"stack":64},
	1367:{"name":"Sea pickle","block":true,"shape":"plant","color":"4f7a44","hardness":0.0,"hidden":true,"stack":64},
	1368:{"name":"Seagrass","color":"4f8f5a","stack":64},
	1390:{"name":"Beacon","block":true,"color":"6fd8d8","hardness":3.0,"light":15},
	1391:{"name":"Beacon beam","block":true,"shape":"plant","color":"ffffff","hardness":0.0,"hidden":true,"light":15},
	1392:{"name":"Nether star","color":"f6f0b8","stack":64},
	1395:{"name":"Totem of Undying","color":"e8c44a","stack":1},
	1380:{"name":"Thing Banner Pattern","color":"e8e0cc","stack":64},
	1381:{"name":"Skull Banner Pattern","color":"e8e0cc","stack":64},
	1382:{"name":"Creeper Banner Pattern","color":"e8e0cc","stack":64},
	1383:{"name":"Flower Banner Pattern","color":"e8e0cc","stack":64},
	1384:{"name":"Bricks Banner Pattern","color":"e8e0cc","stack":64},
	1385:{"name":"Curly border Banner Pattern","color":"e8e0cc","stack":64},
	1386:{"name":"Globe Banner Pattern","color":"e8e0cc","stack":64},
	1387:{"name":"Piglin Banner Pattern","color":"e8e0cc","stack":64},
	1388:{"name":"Guster Banner Pattern","color":"e8e0cc","stack":64},
	1389:{"name":"Flow Banner Pattern","color":"e8e0cc","stack":64},
	1369:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1370:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1371:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1372:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1373:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1374:{"name":"Seagrass","block":true,"shape":"plant","color":"4f8f5a","hardness":0.0,"hidden":true,"drop":1368},
	1291:{"name":"Head","block":true,"shape":"head","color":"4fae4f","hardness":1.0,"stack":64,"hidden":true,"drop":1277},
	1292:{"name":"Head","block":true,"shape":"head","color":"b58a62","hardness":1.0,"stack":64,"hidden":true,"drop":1278},
	1293:{"name":"Head","block":true,"shape":"head","color":"c9c9c9","hardness":1.0,"stack":64,"hidden":true,"drop":1279},
	1294:{"name":"Head","block":true,"shape":"head","color":"3b3b3b","hardness":1.0,"stack":64,"hidden":true,"drop":1280},
	1295:{"name":"Head","block":true,"shape":"head","color":"e2a0a0","hardness":1.0,"stack":64,"hidden":true,"drop":1281},
	1296:{"name":"Head","block":true,"shape":"head","color":"5b6f57","hardness":1.0,"stack":64,"hidden":true,"drop":1282},
	1100:{"name":"Polished blackstone","color":"49434b","block":true,"tool":0,"hardness":2},
	1101:{"name":"Polished blackstone bricks","color":"39333d","block":true,"tool":0,"hardness":1.5},
	1102:{"name":"Chiseled polished blackstone","color":"49414b","block":true,"tool":0,"hardness":1.5},
	1103:{"name":"Gilded blackstone","color":"65513b","block":true,"tool":0,"hardness":1.5},
	1104:{"name":"Crying obsidian","color":"593974","block":true,"tool":0,"hardness":50,"blast_resistance":1200},
	1105:{"name":"Lodestone","color":"858489","block":true,"tool":0,"hardness":3.5},
	1106:{"name":"Banner pattern: Snout","color":"d4b77c","stack":1,"family":"pattern"},
	1107:{"name":"Music disc: Mall","color":"8e61a2","stack":1,"family":"disc"},
	1108:{"name":"Rib armor trim template","color":"928780","family":"template"},
	1109:{"name":"Snout armor trim template","color":"927d70","family":"template"},
	1110:{"name":"Golden pickaxe","color":"e7c253","tool_kind":0,"tier":0,"speed":12,"durability":33,"attack_damage":2,"stack":1,"repair_material":76,"smelt":259},
	1111:{"name":"Golden axe","color":"e7c253","tool_kind":1,"tier":0,"speed":12,"durability":33,"attack_damage":7,"stack":1,"repair_material":76,"smelt":259},
	1112:{"name":"Golden shovel","color":"e7c253","tool_kind":2,"tier":0,"speed":12,"durability":33,"attack_damage":2,"stack":1,"repair_material":76,"smelt":259},
	1113:{"name":"Golden sword","color":"e7c253","tool_kind":3,"tier":0,"speed":12,"durability":33,"attack_damage":4,"stack":1,"repair_material":76,"smelt":259},
	1114:{"name":"Golden hoe","color":"e7c253","tool_kind":4,"tier":0,"speed":12,"durability":33,"attack_damage":1,"stack":1,"repair_material":76,"smelt":259},
	695:{"name":"Nether gold ore","color":"cfa045","block":true,"tool":0,"hardness":3,"smelt":76},
	696:{"name":"Tuff","color":"71746a","block":true,"tool":0,"hardness":1.5},
	697:{"name":"Blackstone","color":"39353f","block":true,"tool":0,"hardness":1.5},
	693:{"name":"Ancient debris","color":"785548","block":true,"hardness":30,"fire_immune":true,"blast_resistance":1200,"smelt":1080},
	694:{"name":"Block of netherite","color":"493c40","block":true,"hardness":50,"fire_immune":true,"blast_resistance":1200},
	1080:{"name":"Netherite scrap","color":"806354","family":"scrap","fire_immune":true},
	1081:{"name":"Netherite ingot","color":"62535b","family":"ingot","fire_immune":true},
	1082:{"name":"Netherite upgrade template","color":"b36c65","family":"template"},
	1090:{"name":"Netherite pickaxe","color":"675766","tool_kind":0,"tier":4,"speed":9.5,"durability":2031,"attack_damage":6,"stack":1,"fire_immune":true,"repair_material":1081},
	1091:{"name":"Netherite axe","color":"675766","tool_kind":1,"tier":4,"speed":9.5,"durability":2031,"attack_damage":10,"stack":1,"fire_immune":true,"repair_material":1081},
	1092:{"name":"Netherite shovel","color":"675766","tool_kind":2,"tier":4,"speed":9.5,"durability":2031,"attack_damage":6,"stack":1,"fire_immune":true,"repair_material":1081},
	1093:{"name":"Netherite sword","color":"675766","tool_kind":3,"tier":4,"speed":9.5,"durability":2031,"attack_damage":9,"stack":1,"fire_immune":true,"repair_material":1081},
	1094:{"name":"Netherite hoe","color":"675766","tool_kind":4,"tier":4,"speed":9.5,"durability":2031,"attack_damage":4,"stack":1,"fire_immune":true,"repair_material":1081},
	1095:{"name":"Netherite helmet","color":"675766","armor":"helmet","armor_material":4,"armor_points":3,"toughness":3,"durability":381,"stack":1,"fire_immune":true,"repair_material":1081},
	1096:{"name":"Netherite chestplate","color":"675766","armor":"chestplate","armor_material":4,"armor_points":8,"toughness":3,"durability":556,"stack":1,"fire_immune":true,"repair_material":1081},
	1097:{"name":"Netherite leggings","color":"675766","armor":"leggings","armor_material":4,"armor_points":6,"toughness":3,"durability":521,"stack":1,"fire_immune":true,"repair_material":1081},
	1098:{"name":"Netherite boots","color":"675766","armor":"boots","armor_material":4,"armor_points":3,"toughness":3,"durability":451,"stack":1,"fire_immune":true,"repair_material":1081},
	950:{"name":"Spider eye","color":"ad5260","food":2},
	683:{"name":"Mud","color":"685e52","block":true,"tool":2},
	684:{"name":"Lily pad","color":"497347","block":true,"shape":"carpet"},
	685:{"name":"Swamp grass","color":"667c43","block":true,"tool":2},
	686:{"name":"Kelp plant","color":"608453","block":true,"shape":"crop","crop":"kelp","stage":3},
	687:{"name":"Cocoa pod (growing)","color":"719047","block":true,"shape":"crop","crop":"cocoa","stage":0},
	688:{"name":"Cocoa pod (ripe)","color":"9f643c","block":true,"shape":"crop","crop":"cocoa","stage":3},
	930:{"name":"Lead","color":"b79661"},
	512:{"name":"Emerald ore","color":"709786","block":true},
	513:{"name":"Deepslate emerald ore","color":"45645d","block":true},
	514:{"name":"Block of emerald","color":"35b979","block":true},
	515:{"name":"Blast furnace","color":"757d81","block":true},
	516:{"name":"Smoker","color":"705945","block":true},
	517:{"name":"Cartography table","color":"b29460","block":true,"tool":1},
	518:{"name":"Brewing stand","color":"b3954d","block":true,"shape":"brewing"},
	519:{"name":"Composter","color":"937043","block":true,"tool":1,"shape":"composter","hardness":0.6},
	520:{"name":"Barrel","color":"9d774f","block":true,"tool":1},
	521:{"name":"Fletching table","color":"c4a97a","block":true,"tool":1},
	522:{"name":"Cauldron","color":"535b62","block":true,"shape":"cauldron"},
	523:{"name":"Lectern","color":"ba8a51","block":true,"shape":"lectern","tool":1},
	524:{"name":"Stonecutter","color":"8c938f","block":true,"shape":"stonecutter"},
	525:{"name":"Loom","color":"a97b51","block":true,"tool":1},
	526:{"name":"Smithing table","color":"574640","block":true},
	527:{"name":"Grindstone","color":"98958b","block":true,"shape":"grindstone"},
	528:{"name":"Bell","color":"e1b84d","block":true,"shape":"bell"},
	529:{"name":"Dirt path","color":"ad9569","block":true},
	530:{"name":"Lantern","color":"efb461","block":true,"shape":"lantern"},
	531:{"name":"Campfire","color":"b57843","block":true,"shape":"campfire","tool":1,"hardness":2.0},
	1200:{"name":"Name tag","color":"d2bb83","family":"name_tag"},
	1201:{"name":"Nautilus shell","color":"dba673","family":"nautilus_shell"},
	1220:{"name":"Unlit campfire","color":"695242","block":true,"shape":"campfire","tool":1,"hardness":2.0,"hidden":true},
	1221:{"name":"Soul campfire","color":"4cbec6","block":true,"shape":"campfire","tool":1,"hardness":2.0},
	1222:{"name":"Unlit soul campfire","color":"675c51","block":true,"shape":"campfire","tool":1,"hardness":2.0,"hidden":true},
	1223:{"name":"Soul soil","color":"554039","block":true,"tool":2,"hardness":0.5},
	532:{"name":"Anvil","color":"505659","block":true,"shape":"anvil"},
	533:{"name":"Granite","color":"a67769","block":true},
	534:{"name":"Diorite","color":"c4c1b8","block":true},
	535:{"name":"Andesite","color":"848b89","block":true},
	536:{"name":"Polished granite","color":"ba897a","block":true},
	537:{"name":"Polished diorite","color":"ded8c9","block":true},
	538:{"name":"Polished andesite","color":"a7afaa","block":true},
	539:{"name":"Chiseled stone bricks","color":"878b85","block":true},
	540:{"name":"Dripstone block","color":"a58a74","block":true},
	541:{"name":"Quartz block","color":"e4dccc","block":true},
	542:{"name":"Quartz pillar","color":"e4dccc","block":true},
	543:{"name":"Glass pane","color":"b9dcd8","block":true,"shape":"pane"},
	544:{"name":"Dried kelp block","color":"576446","block":true},
	545:{"name":"Item frame","color":"b08251","block":true,"shape":"frame"},
	546:{"name":"Painting","color":"76ab9c","block":true,"shape":"painting"},
	547:{"name":"Red candle","color":"cb5047","block":true,"shape":"candle"},
	548:{"name":"Yellow candle","color":"edc657","block":true,"shape":"candle"},
	549:{"name":"Wooden door","color":"a57948","block":true,"shape":"door","tool":1},
	550:{"name":"Open wooden door","color":"a57948","block":true,"shape":"door_open","tool":1},
	551:CropFarming.DATA[551],
	552:CropFarming.DATA[552],
	553:CropFarming.DATA[553],
	554:CropFarming.DATA[554],
	555:CropFarming.DATA[555],
	556:CropFarming.DATA[556],
	557:CropFarming.DATA[557],
	558:CropFarming.DATA[558],
	559:CropFarming.DATA[559],
	560:CropFarming.DATA[560],
	561:CropFarming.DATA[561],
	562:CropFarming.DATA[562],
	563:{"name":"Nether wart (growing)","color":"a34140","block":true,"shape":"crop","crop":"nether_wart","stage":0,"tool":-1},
	564:{"name":"Nether wart (growing)","color":"a34140","block":true,"shape":"crop","crop":"nether_wart","stage":1,"tool":-1},
	565:{"name":"Nether wart (growing)","color":"a34140","block":true,"shape":"crop","crop":"nether_wart","stage":2,"tool":-1},
	566:{"name":"Nether wart (ripe)","color":"a34140","block":true,"shape":"crop","crop":"nether_wart","stage":3,"tool":-1},
	567:{"name":"Sweet berries (growing)","color":"b64853","block":true,"shape":"crop","crop":"sweet_berries","stage":0,"tool":-1},
	568:{"name":"Sweet berries (growing)","color":"b64853","block":true,"shape":"crop","crop":"sweet_berries","stage":1,"tool":-1},
	569:{"name":"Sweet berries (growing)","color":"b64853","block":true,"shape":"crop","crop":"sweet_berries","stage":2,"tool":-1},
	570:{"name":"Sweet berries (ripe)","color":"b64853","block":true,"shape":"crop","crop":"sweet_berries","stage":3,"tool":-1},
	768:{"name":"Emerald","color":"45d58c"},
	769:{"name":"Carrot","color":"ed8c37","food":3},
	770:{"name":"Potato","color":"bf995f","food":1,"smelt":771},
	771:{"name":"Baked potato","color":"c5995f","food":5},
	772:{"name":"Beetroot","color":"ac3c57","food":1},
	773:{"name":"Beetroot seeds","color":"a59962"},
	774:{"name":"Nether wart","color":"a43c41"},
	775:{"name":"Sweet berries","color":"c74953","food":2},
	776:{"name":"Golden carrot","color":"efc950","food":6},
	777:{"name":"Glistering melon slice","color":"ddaa42"},
	778:{"name":"Cookie","color":"b37e42","food":2},
	779:{"name":"Cake","color":"f0d4a5","block":true,"shape":"cake","stack":1},
	780:{"name":"Suspicious stew","color":"a89556","food":6,"stack":1},
	781:{"name":"Beetroot soup","color":"a44b4a","food":6,"stack":1},
	782:{"name":"Raw cod","color":"a3bba0","food":2,"smelt":783},
	783:{"name":"Cooked cod","color":"bfb18c","food":5},
	784:{"name":"Raw salmon","color":"c67669","food":2,"smelt":785},
	785:{"name":"Cooked salmon","color":"c18d76","food":6},
	786:{"name":"Tropical fish","color":"efaa4c","food":1},
	787:{"name":"Pufferfish","color":"c9b153","food":1},
	788:{"name":"Bucket of cod","color":"9bbac5","stack":1},
	789:{"name":"Fishing rod","color":"ba955b","stack":1,"durability":65},
	790:{"name":"Crossbow","color":"9f7951","stack":1,"durability":466},
	791:{"name":"Enchanted book","color":"a9609e","stack":1},
	792:{"name":"Ink sac","color":"343745"},
	793:{"name":"Raw beef","color":"b9554e","food":3,"smelt":794},
	794:{"name":"Steak","color":"895c41","food":8},
	795:{"name":"Raw porkchop","color":"d48982","food":3,"smelt":796},
	796:{"name":"Cooked porkchop","color":"b67e5c","food":8},
	797:{"name":"Raw chicken","color":"dcc1a0","food":2,"smelt":798},
	798:{"name":"Cooked chicken","color":"b5895f","food":6},
	799:{"name":"Raw mutton","color":"b35252","food":2,"smelt":800},
	800:{"name":"Cooked mutton","color":"945c48","food":6},
	801:{"name":"Raw rabbit","color":"c2938b","food":3,"smelt":802},
	802:{"name":"Cooked rabbit","color":"a07a5c","food":5},
	803:{"name":"Rabbit stew","color":"aa844a","food":10,"stack":1},
	804:{"name":"Rabbit hide","color":"b5a186"},
	805:{"name":"Rabbit foot","color":"c7b89c"},
	806:{"name":"Leather horse armor","color":"ab7953","stack":1},
	807:{"name":"Glass bottle","color":"b4d3d2"},
	808:{"name":"Water bottle","color":"8091ff","family":"potion","stack":1,"effect":"water"},
	809:{"name":"Bottle o enchanting","color":"8ec66e","stack":64},
	810:{"name":"Empty map","color":"dbcea5","stack":64},
	811:{"name":"Map","color":"c6ca9b","stack":1},
	812:{"name":"Globe banner pattern","color":"e5d5a8","stack":1},
	813:{"name":"Shield","color":"a6865b","stack":1,"durability":337},
	814:{"name":"Kelp","color":"66965b","food":0,"smelt":815},
	815:{"name":"Dried kelp","color":"718353","food":1},
	816:{"name":"Cocoa beans","color":"825136"},
	817:{"name":"Chainmail helmet","color":"a5afad","stack":1,"armor":"helmet","durability":240},
	818:{"name":"Chainmail chestplate","color":"a5afad","stack":1,"armor":"chestplate","durability":240},
	819:{"name":"Chainmail leggings","color":"a5afad","stack":1,"armor":"leggings","durability":240},
	820:{"name":"Chainmail boots","color":"a5afad","stack":1,"armor":"boots","durability":240},
	571:{"name":"White wool","color":"e4e4d7","block":true,"shape":"cube","family":"wool","dye":"white"},
	572:{"name":"Grey wool","color":"626c70","block":true,"shape":"cube","family":"wool","dye":"grey"},
	573:{"name":"Light grey wool","color":"b0b4ac","block":true,"shape":"cube","family":"wool","dye":"silver"},
	574:{"name":"Black wool","color":"333740","block":true,"shape":"cube","family":"wool","dye":"black"},
	575:{"name":"Yellow wool","color":"edc647","block":true,"shape":"cube","family":"wool","dye":"yellow"},
	576:{"name":"Orange wool","color":"e4943e","block":true,"shape":"cube","family":"wool","dye":"orange"},
	577:{"name":"Red wool","color":"b83d41","block":true,"shape":"cube","family":"wool","dye":"red"},
	578:{"name":"Magenta wool","color":"b94baf","block":true,"shape":"cube","family":"wool","dye":"magenta"},
	579:{"name":"Purple wool","color":"824aaa","block":true,"shape":"cube","family":"wool","dye":"purple"},
	580:{"name":"Blue wool","color":"4966ad","block":true,"shape":"cube","family":"wool","dye":"blue"},
	581:{"name":"Cyan wool","color":"378a99","block":true,"shape":"cube","family":"wool","dye":"cyan"},
	582:{"name":"Lime wool","color":"8bbe45","block":true,"shape":"cube","family":"wool","dye":"lime"},
	583:{"name":"Green wool","color":"51763e","block":true,"shape":"cube","family":"wool","dye":"green"},
	584:{"name":"Pink wool","color":"dd8eac","block":true,"shape":"cube","family":"wool","dye":"pink"},
	585:{"name":"Light blue wool","color":"79b4d2","block":true,"shape":"cube","family":"wool","dye":"light_blue"},
	586:{"name":"Brown wool","color":"79563e","block":true,"shape":"cube","family":"wool","dye":"brown"},
	587:{"name":"White carpet","color":"e4e4d7","block":true,"shape":"carpet","family":"carpet","dye":"white"},
	588:{"name":"Grey carpet","color":"626c70","block":true,"shape":"carpet","family":"carpet","dye":"grey"},
	589:{"name":"Light grey carpet","color":"b0b4ac","block":true,"shape":"carpet","family":"carpet","dye":"silver"},
	590:{"name":"Black carpet","color":"333740","block":true,"shape":"carpet","family":"carpet","dye":"black"},
	591:{"name":"Yellow carpet","color":"edc647","block":true,"shape":"carpet","family":"carpet","dye":"yellow"},
	592:{"name":"Orange carpet","color":"e4943e","block":true,"shape":"carpet","family":"carpet","dye":"orange"},
	593:{"name":"Red carpet","color":"b83d41","block":true,"shape":"carpet","family":"carpet","dye":"red"},
	594:{"name":"Magenta carpet","color":"b94baf","block":true,"shape":"carpet","family":"carpet","dye":"magenta"},
	595:{"name":"Purple carpet","color":"824aaa","block":true,"shape":"carpet","family":"carpet","dye":"purple"},
	596:{"name":"Blue carpet","color":"4966ad","block":true,"shape":"carpet","family":"carpet","dye":"blue"},
	597:{"name":"Cyan carpet","color":"378a99","block":true,"shape":"carpet","family":"carpet","dye":"cyan"},
	598:{"name":"Lime carpet","color":"8bbe45","block":true,"shape":"carpet","family":"carpet","dye":"lime"},
	599:{"name":"Green carpet","color":"51763e","block":true,"shape":"carpet","family":"carpet","dye":"green"},
	600:{"name":"Pink carpet","color":"dd8eac","block":true,"shape":"carpet","family":"carpet","dye":"pink"},
	601:{"name":"Light blue carpet","color":"79b4d2","block":true,"shape":"carpet","family":"carpet","dye":"light_blue"},
	602:{"name":"Brown carpet","color":"79563e","block":true,"shape":"carpet","family":"carpet","dye":"brown"},
	603:{"name":"White terracotta","color":"e4e4d7","block":true,"shape":"cube","family":"terracotta","dye":"white","smelt":619},
	604:{"name":"Grey terracotta","color":"626c70","block":true,"shape":"cube","family":"terracotta","dye":"grey","smelt":620},
	605:{"name":"Light grey terracotta","color":"b0b4ac","block":true,"shape":"cube","family":"terracotta","dye":"silver","smelt":621},
	606:{"name":"Black terracotta","color":"333740","block":true,"shape":"cube","family":"terracotta","dye":"black","smelt":622},
	607:{"name":"Yellow terracotta","color":"edc647","block":true,"shape":"cube","family":"terracotta","dye":"yellow","smelt":623},
	608:{"name":"Orange terracotta","color":"e4943e","block":true,"shape":"cube","family":"terracotta","dye":"orange","smelt":624},
	609:{"name":"Red terracotta","color":"b83d41","block":true,"shape":"cube","family":"terracotta","dye":"red","smelt":625},
	610:{"name":"Magenta terracotta","color":"b94baf","block":true,"shape":"cube","family":"terracotta","dye":"magenta","smelt":626},
	611:{"name":"Purple terracotta","color":"824aaa","block":true,"shape":"cube","family":"terracotta","dye":"purple","smelt":627},
	612:{"name":"Blue terracotta","color":"4966ad","block":true,"shape":"cube","family":"terracotta","dye":"blue","smelt":628},
	613:{"name":"Cyan terracotta","color":"378a99","block":true,"shape":"cube","family":"terracotta","dye":"cyan","smelt":629},
	614:{"name":"Lime terracotta","color":"8bbe45","block":true,"shape":"cube","family":"terracotta","dye":"lime","smelt":630},
	615:{"name":"Green terracotta","color":"51763e","block":true,"shape":"cube","family":"terracotta","dye":"green","smelt":631},
	616:{"name":"Pink terracotta","color":"dd8eac","block":true,"shape":"cube","family":"terracotta","dye":"pink","smelt":632},
	617:{"name":"Light blue terracotta","color":"79b4d2","block":true,"shape":"cube","family":"terracotta","dye":"light_blue","smelt":633},
	618:{"name":"Brown terracotta","color":"79563e","block":true,"shape":"cube","family":"terracotta","dye":"brown","smelt":634},
	# Concrete (mcl_colorblocks). Powder falls and hardens in water; the concrete it
	# becomes is the plain building block. The behaviour lives in `Concrete`.
	11040:{"name":"White concrete powder","color":"d8d2c6","block":true,"shape":"cube","family":"concrete_powder","dye":"white","hardness":0.5,"tool":2},
	11041:{"name":"Grey concrete powder","color":"9a9a92","block":true,"shape":"cube","family":"concrete_powder","dye":"grey","hardness":0.5,"tool":2},
	11042:{"name":"Light grey concrete powder","color":"b6b4ac","block":true,"shape":"cube","family":"concrete_powder","dye":"silver","hardness":0.5,"tool":2},
	11043:{"name":"Black concrete powder","color":"6b6b66","block":true,"shape":"cube","family":"concrete_powder","dye":"black","hardness":0.5,"tool":2},
	11044:{"name":"Yellow concrete powder","color":"dcbf85","block":true,"shape":"cube","family":"concrete_powder","dye":"yellow","hardness":0.5,"tool":2},
	11045:{"name":"Orange concrete powder","color":"dcae83","block":true,"shape":"cube","family":"concrete_powder","dye":"orange","hardness":0.5,"tool":2},
	11046:{"name":"Red concrete powder","color":"c08884","block":true,"shape":"cube","family":"concrete_powder","dye":"red","hardness":0.5,"tool":2},
	11047:{"name":"Magenta concrete powder","color":"bf93b7","block":true,"shape":"cube","family":"concrete_powder","dye":"magenta","hardness":0.5,"tool":2},
	11048:{"name":"Purple concrete powder","color":"9f8dba","block":true,"shape":"cube","family":"concrete_powder","dye":"purple","hardness":0.5,"tool":2},
	11049:{"name":"Blue concrete powder","color":"8493be","block":true,"shape":"cube","family":"concrete_powder","dye":"blue","hardness":0.5,"tool":2},
	11050:{"name":"Cyan concrete powder","color":"7ea4ac","block":true,"shape":"cube","family":"concrete_powder","dye":"cyan","hardness":0.5,"tool":2},
	11051:{"name":"Lime concrete powder","color":"b2c184","block":true,"shape":"cube","family":"concrete_powder","dye":"lime","hardness":0.5,"tool":2},
	11052:{"name":"Green concrete powder","color":"89987f","block":true,"shape":"cube","family":"concrete_powder","dye":"green","hardness":0.5,"tool":2},
	11053:{"name":"Pink concrete powder","color":"d8acbe","block":true,"shape":"cube","family":"concrete_powder","dye":"pink","hardness":0.5,"tool":2},
	11054:{"name":"Light blue concrete powder","color":"a3becd","block":true,"shape":"cube","family":"concrete_powder","dye":"light_blue","hardness":0.5,"tool":2},
	11055:{"name":"Brown concrete powder","color":"9d8471","block":true,"shape":"cube","family":"concrete_powder","dye":"brown","hardness":0.5,"tool":2},
	11056:{"name":"White concrete","color":"e8e8e0","block":true,"shape":"cube","family":"concrete","dye":"white","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11057:{"name":"Grey concrete","color":"74746f","block":true,"shape":"cube","family":"concrete","dye":"grey","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11058:{"name":"Light grey concrete","color":"a9a9a2","block":true,"shape":"cube","family":"concrete","dye":"silver","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11059:{"name":"Black concrete","color":"3d3d40","block":true,"shape":"cube","family":"concrete","dye":"black","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11060:{"name":"Yellow concrete","color":"e6c33c","block":true,"shape":"cube","family":"concrete","dye":"yellow","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11061:{"name":"Orange concrete","color":"e08a35","block":true,"shape":"cube","family":"concrete","dye":"orange","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11062:{"name":"Red concrete","color":"a8353a","block":true,"shape":"cube","family":"concrete","dye":"red","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11063:{"name":"Magenta concrete","color":"b044a6","block":true,"shape":"cube","family":"concrete","dye":"magenta","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11064:{"name":"Purple concrete","color":"7440a2","block":true,"shape":"cube","family":"concrete","dye":"purple","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11065:{"name":"Blue concrete","color":"3c53a5","block":true,"shape":"cube","family":"concrete","dye":"blue","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11066:{"name":"Cyan concrete","color":"2c7a8c","block":true,"shape":"cube","family":"concrete","dye":"cyan","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11067:{"name":"Lime concrete","color":"7db83b","block":true,"shape":"cube","family":"concrete","dye":"lime","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11068:{"name":"Green concrete","color":"3f6b30","block":true,"shape":"cube","family":"concrete","dye":"green","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11069:{"name":"Pink concrete","color":"d5698f","block":true,"shape":"cube","family":"concrete","dye":"pink","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11070:{"name":"Light blue concrete","color":"60a3cf","block":true,"shape":"cube","family":"concrete","dye":"light_blue","hardness":1.8,"tool":0,"blast_resistance":6.0},
	11071:{"name":"Brown concrete","color":"6d4a30","block":true,"shape":"cube","family":"concrete","dye":"brown","hardness":1.8,"tool":0,"blast_resistance":6.0},
	# Candles (mcl_candles): per colour four unlit counts then four lit counts.
	# The count is the source's own scheme; the lit run uses `light_source = 3 * n`.
	11072:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"stack":64},
	11073:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11074:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11075:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11080:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"stack":64},
	11081:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11082:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11083:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11088:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"stack":64},
	11089:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11090:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11091:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11096:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"stack":64},
	11097:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11098:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11099:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11104:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"stack":64},
	11105:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11106:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11107:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11112:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"stack":64},
	11113:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11114:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11115:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11120:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"stack":64},
	11121:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11122:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11123:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11128:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"stack":64},
	11129:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11130:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11131:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11136:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"stack":64},
	11137:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11138:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11139:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11144:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"stack":64},
	11145:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11146:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11147:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11152:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"stack":64},
	11153:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11154:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11155:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11160:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"stack":64},
	11161:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11162:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11163:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11168:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"stack":64},
	11169:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11170:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11171:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11176:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"stack":64},
	11177:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11178:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11179:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11184:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"stack":64},
	11185:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11186:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11187:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11192:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"stack":64},
	11193:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11194:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11195:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"stack":64,"hidden":true},
	11076:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"hidden":true},
	11077:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"hidden":true},
	11078:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"hidden":true},
	11079:{"name":"White candle","color":"e4e4d7","block":true,"shape":"candle","family":"candle","dye":"white","hardness":0.1,"tool":-1,"hidden":true},
	11084:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"hidden":true},
	11085:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"hidden":true},
	11086:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"hidden":true},
	11087:{"name":"Grey candle","color":"626c70","block":true,"shape":"candle","family":"candle","dye":"grey","hardness":0.1,"tool":-1,"hidden":true},
	11092:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"hidden":true},
	11093:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"hidden":true},
	11094:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"hidden":true},
	11095:{"name":"Silver candle","color":"b0b4ac","block":true,"shape":"candle","family":"candle","dye":"silver","hardness":0.1,"tool":-1,"hidden":true},
	11100:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"hidden":true},
	11101:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"hidden":true},
	11102:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"hidden":true},
	11103:{"name":"Black candle","color":"333740","block":true,"shape":"candle","family":"candle","dye":"black","hardness":0.1,"tool":-1,"hidden":true},
	11108:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"hidden":true},
	11109:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"hidden":true},
	11110:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"hidden":true},
	11111:{"name":"Yellow candle","color":"edc647","block":true,"shape":"candle","family":"candle","dye":"yellow","hardness":0.1,"tool":-1,"hidden":true},
	11116:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"hidden":true},
	11117:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"hidden":true},
	11118:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"hidden":true},
	11119:{"name":"Orange candle","color":"e4943e","block":true,"shape":"candle","family":"candle","dye":"orange","hardness":0.1,"tool":-1,"hidden":true},
	11124:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"hidden":true},
	11125:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"hidden":true},
	11126:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"hidden":true},
	11127:{"name":"Red candle","color":"b83d41","block":true,"shape":"candle","family":"candle","dye":"red","hardness":0.1,"tool":-1,"hidden":true},
	11132:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"hidden":true},
	11133:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"hidden":true},
	11134:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"hidden":true},
	11135:{"name":"Magenta candle","color":"b94baf","block":true,"shape":"candle","family":"candle","dye":"magenta","hardness":0.1,"tool":-1,"hidden":true},
	11140:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"hidden":true},
	11141:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"hidden":true},
	11142:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"hidden":true},
	11143:{"name":"Purple candle","color":"824aaa","block":true,"shape":"candle","family":"candle","dye":"purple","hardness":0.1,"tool":-1,"hidden":true},
	11148:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"hidden":true},
	11149:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"hidden":true},
	11150:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"hidden":true},
	11151:{"name":"Blue candle","color":"4966ad","block":true,"shape":"candle","family":"candle","dye":"blue","hardness":0.1,"tool":-1,"hidden":true},
	11156:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"hidden":true},
	11157:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"hidden":true},
	11158:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"hidden":true},
	11159:{"name":"Cyan candle","color":"378a99","block":true,"shape":"candle","family":"candle","dye":"cyan","hardness":0.1,"tool":-1,"hidden":true},
	11164:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"hidden":true},
	11165:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"hidden":true},
	11166:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"hidden":true},
	11167:{"name":"Lime candle","color":"8bbe45","block":true,"shape":"candle","family":"candle","dye":"lime","hardness":0.1,"tool":-1,"hidden":true},
	11172:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"hidden":true},
	11173:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"hidden":true},
	11174:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"hidden":true},
	11175:{"name":"Green candle","color":"51763e","block":true,"shape":"candle","family":"candle","dye":"green","hardness":0.1,"tool":-1,"hidden":true},
	11180:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"hidden":true},
	11181:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"hidden":true},
	11182:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"hidden":true},
	11183:{"name":"Pink candle","color":"dd8eac","block":true,"shape":"candle","family":"candle","dye":"pink","hardness":0.1,"tool":-1,"hidden":true},
	11188:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"hidden":true},
	11189:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"hidden":true},
	11190:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"hidden":true},
	11191:{"name":"Light blue candle","color":"79b4d2","block":true,"shape":"candle","family":"candle","dye":"light_blue","hardness":0.1,"tool":-1,"hidden":true},
	11196:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"hidden":true},
	11197:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"hidden":true},
	11198:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"hidden":true},
	11199:{"name":"Brown candle","color":"79563e","block":true,"shape":"candle","family":"candle","dye":"brown","hardness":0.1,"tool":-1,"hidden":true},
	11280:{"name":"Cake","color":"f0d4a5","block":true,"shape":"cake_candles","family":"candle_cake","hardness":0.5,"tool":-1,"hidden":true},
	11281:{"name":"Cake","color":"f0d4a5","block":true,"shape":"cake_candles","family":"candle_cake","hidden":true},
	11200:NetherBlocks.DATA[11200],
	11201:NetherBlocks.DATA[11201],
	11202:NetherBlocks.DATA[11202],
	11203:NetherBlocks.DATA[11203],
	11204:NetherBlocks.DATA[11204],
	11205:NetherBlocks.DATA[11205],
	11206:NetherBlocks.DATA[11206],
	11207:NetherBlocks.DATA[11207],
	11208:NetherBlocks.DATA[11208],
	11209:NetherBlocks.DATA[11209],
	11210:GlassColors.DATA[11210],
	11211:GlassColors.DATA[11211],
	11212:GlassColors.DATA[11212],
	11213:GlassColors.DATA[11213],
	11214:GlassColors.DATA[11214],
	11215:GlassColors.DATA[11215],
	11216:GlassColors.DATA[11216],
	11217:GlassColors.DATA[11217],
	11218:GlassColors.DATA[11218],
	11219:GlassColors.DATA[11219],
	11220:GlassColors.DATA[11220],
	11221:GlassColors.DATA[11221],
	11222:GlassColors.DATA[11222],
	11223:GlassColors.DATA[11223],
	11224:GlassColors.DATA[11224],
	11225:GlassColors.DATA[11225],
	11226:GlassColors.DATA[11226],
	11227:GlassColors.DATA[11227],
	11228:GlassColors.DATA[11228],
	11229:GlassColors.DATA[11229],
	11230:GlassColors.DATA[11230],
	11231:GlassColors.DATA[11231],
	11232:GlassColors.DATA[11232],
	11233:GlassColors.DATA[11233],
	11234:GlassColors.DATA[11234],
	11235:GlassColors.DATA[11235],
	11236:GlassColors.DATA[11236],
	11237:GlassColors.DATA[11237],
	11238:GlassColors.DATA[11238],
	11239:GlassColors.DATA[11239],
	11240:GlassColors.DATA[11240],
	11241:GlassColors.DATA[11241],
	11490:{"name":"Sentry armor trim template","color":"928780","family":"template","stack":64},
	11491:{"name":"Dune armor trim template","color":"928780","family":"template","stack":64},
	11492:{"name":"Coast armor trim template","color":"928780","family":"template","stack":64},
	11493:{"name":"Wild armor trim template","color":"928780","family":"template","stack":64},
	11494:{"name":"Tide armor trim template","color":"928780","family":"template","stack":64},
	11495:{"name":"Ward armor trim template","color":"928780","family":"template","stack":64},
	11496:{"name":"Vex armor trim template","color":"928780","family":"template","stack":64},
	11497:{"name":"Rib armor trim template","color":"928780","family":"template","stack":64},
	11498:{"name":"Snout armor trim template","color":"928780","family":"template","stack":64},
	11499:{"name":"Eye armor trim template","color":"928780","family":"template","stack":64},
	11500:{"name":"Spire armor trim template","color":"928780","family":"template","stack":64},
	11501:{"name":"Silence armor trim template","color":"928780","family":"template","stack":64},
	11502:{"name":"Wayfinder armor trim template","color":"928780","family":"template","stack":64},
	11503:{"name":"Bolt armor trim template","color":"928780","family":"template","stack":64},
	11504:{"name":"Flow armor trim template","color":"928780","family":"template","stack":64},
	11505:{"name":"Host armor trim template","color":"928780","family":"template","stack":64},
	11506:{"name":"Raiser armor trim template","color":"928780","family":"template","stack":64},
	11440:EndMud.DATA[11440],
	11441:EndMud.DATA[11441],
	11442:EndMud.DATA[11442],
	11443:EndMud.DATA[11443],
	11444:EndMud.DATA[11444],
	11445:EndMud.DATA[11445],
	11400:FlowersExtra.DATA[11400],
	11401:FlowersExtra.DATA[11401],
	11402:FlowersExtra.DATA[11402],
	11403:FlowersExtra.DATA[11403],
	11404:FlowersExtra.DATA[11404],
	11405:FlowersExtra.DATA[11405],
	11406:FlowersExtra.DATA[11406],
	11407:FlowersExtra.DATA[11407],
	11408:FlowersExtra.DATA[11408],
	11409:FlowersExtra.DATA[11409],
	11410:FlowersExtra.DATA[11410],
	11411:FlowersExtra.DATA[11411],
	11412:FlowersExtra.DATA[11412],
	11413:FlowersExtra.DATA[11413],
	11414:FlowersExtra.DATA[11414],
	11415:FlowersExtra.DATA[11415],
	11416:FlowersExtra.DATA[11416],
	11417:FlowersExtra.DATA[11417],
	11507:Sculk.DATA[11507],
	11508:Sculk.DATA[11508],
	11509:Sculk.DATA[11509],
	11510:Sculk.DATA[11510],
	11300:RawOres.DATA[11300],
	11301:RawOres.DATA[11301],
	11302:RawOres.DATA[11302],
	11303:RawOres.DATA[11303],
	11304:RawOres.DATA[11304],
	11305:RawOres.DATA[11305],
	11306:RawOres.DATA[11306],
	11470:LushCaveExtra.DATA[11470],
	11471:LushCaveExtra.DATA[11471],
	11472:LushCaveExtra.DATA[11472],
	11473:LushCaveExtra.DATA[11473],
	11474:LushCaveExtra.DATA[11474],
	11475:LushCaveExtra.DATA[11475],
	11476:LushCaveExtra.DATA[11476],
	11477:LushCaveExtra.DATA[11477],
	11478:LushCaveExtra.DATA[11478],
	11479:LushCaveExtra.DATA[11479],
	11480:LushCaveExtra.DATA[11480],
	11481:LushCaveExtra.DATA[11481],
	# `mcl_anvils`: the two damaged anvil states, which the source registers as
	# `anvil_damage_1` and `anvil_damage_2`. Both drop a plain anvil and never appear
	# in the catalog.
	11446:{"name":"Anvil","color":"4a4a4f","block":true,"hardness":1.5,"tool":0,"blast_resistance":1200,"family":"anvil","drop":532,"hidden":true},
	11447:{"name":"Anvil","color":"434348","block":true,"hardness":1.5,"tool":0,"blast_resistance":1200,"family":"anvil","drop":532,"hidden":true},
	11519:PaleOak.DATA[11519],
	11520:PaleOak.DATA[11520],
	11521:PaleOak.DATA[11521],
	11522:PaleOak.DATA[11522],
	11523:PaleOak.DATA[11523],
	11524:PaleOak.DATA[11524],
	11525:PaleOak.DATA[11525],
	11526:PaleOak.DATA[11526],
	11527:PaleOak.DATA[11527],
	11528:PaleOak.DATA[11528],
	11529:PaleOak.DATA[11529],
	11546:Bookshelves.DATA[11546],
	11530:CopperDecor.DATA[11530],
	11531:CopperDecor.DATA[11531],
	11532:CopperDecor.DATA[11532],
	11533:CopperDecor.DATA[11533],
	11534:CopperDecor.DATA[11534],
	11535:CopperDecor.DATA[11535],
	11536:CopperDecor.DATA[11536],
	11537:CopperDecor.DATA[11537],
	11538:CopperDecor.DATA[11538],
	11539:CopperDecor.DATA[11539],
	11540:CopperDecor.DATA[11540],
	11541:CopperDecor.DATA[11541],
	11542:CopperDecor.DATA[11542],
	11543:CopperDecor.DATA[11543],
	11544:CopperDecor.DATA[11544],
	11545:CopperDecor.DATA[11545],
	11511:CrimsonPlants.DATA[11511],
	11512:CrimsonPlants.DATA[11512],
	11513:CrimsonPlants.DATA[11513],
	11514:CrimsonPlants.DATA[11514],
	11515:CrimsonPlants.DATA[11515],
	11516:CrimsonPlants.DATA[11516],
	11517:CrimsonPlants.DATA[11517],
	11518:CrimsonPlants.DATA[11518],
	619:{"name":"White glazed terracotta","color":"e4e4d7","block":true,"shape":"cube","family":"glazed","dye":"white"},
	620:{"name":"Grey glazed terracotta","color":"626c70","block":true,"shape":"cube","family":"glazed","dye":"grey"},
	621:{"name":"Light grey glazed terracotta","color":"b0b4ac","block":true,"shape":"cube","family":"glazed","dye":"silver"},
	622:{"name":"Black glazed terracotta","color":"333740","block":true,"shape":"cube","family":"glazed","dye":"black"},
	623:{"name":"Yellow glazed terracotta","color":"edc647","block":true,"shape":"cube","family":"glazed","dye":"yellow"},
	624:{"name":"Orange glazed terracotta","color":"e4943e","block":true,"shape":"cube","family":"glazed","dye":"orange"},
	625:{"name":"Red glazed terracotta","color":"b83d41","block":true,"shape":"cube","family":"glazed","dye":"red"},
	626:{"name":"Magenta glazed terracotta","color":"b94baf","block":true,"shape":"cube","family":"glazed","dye":"magenta"},
	627:{"name":"Purple glazed terracotta","color":"824aaa","block":true,"shape":"cube","family":"glazed","dye":"purple"},
	628:{"name":"Blue glazed terracotta","color":"4966ad","block":true,"shape":"cube","family":"glazed","dye":"blue"},
	629:{"name":"Cyan glazed terracotta","color":"378a99","block":true,"shape":"cube","family":"glazed","dye":"cyan"},
	630:{"name":"Lime glazed terracotta","color":"8bbe45","block":true,"shape":"cube","family":"glazed","dye":"lime"},
	631:{"name":"Green glazed terracotta","color":"51763e","block":true,"shape":"cube","family":"glazed","dye":"green"},
	632:{"name":"Pink glazed terracotta","color":"dd8eac","block":true,"shape":"cube","family":"glazed","dye":"pink"},
	633:{"name":"Light blue glazed terracotta","color":"79b4d2","block":true,"shape":"cube","family":"glazed","dye":"light_blue"},
	634:{"name":"Brown glazed terracotta","color":"79563e","block":true,"shape":"cube","family":"glazed","dye":"brown"},
	635:{"name":"White banner","color":"e4e4d7","block":true,"shape":"banner","family":"banner","dye":"white"},
	636:{"name":"Grey banner","color":"626c70","block":true,"shape":"banner","family":"banner","dye":"grey"},
	637:{"name":"Light grey banner","color":"b0b4ac","block":true,"shape":"banner","family":"banner","dye":"silver"},
	638:{"name":"Black banner","color":"333740","block":true,"shape":"banner","family":"banner","dye":"black"},
	639:{"name":"Yellow banner","color":"edc647","block":true,"shape":"banner","family":"banner","dye":"yellow"},
	640:{"name":"Orange banner","color":"e4943e","block":true,"shape":"banner","family":"banner","dye":"orange"},
	641:{"name":"Red banner","color":"b83d41","block":true,"shape":"banner","family":"banner","dye":"red"},
	642:{"name":"Magenta banner","color":"b94baf","block":true,"shape":"banner","family":"banner","dye":"magenta"},
	643:{"name":"Purple banner","color":"824aaa","block":true,"shape":"banner","family":"banner","dye":"purple"},
	644:{"name":"Blue banner","color":"4966ad","block":true,"shape":"banner","family":"banner","dye":"blue"},
	645:{"name":"Cyan banner","color":"378a99","block":true,"shape":"banner","family":"banner","dye":"cyan"},
	646:{"name":"Lime banner","color":"8bbe45","block":true,"shape":"banner","family":"banner","dye":"lime"},
	647:{"name":"Green banner","color":"51763e","block":true,"shape":"banner","family":"banner","dye":"green"},
	648:{"name":"Pink banner","color":"dd8eac","block":true,"shape":"banner","family":"banner","dye":"pink"},
	649:{"name":"Light blue banner","color":"79b4d2","block":true,"shape":"banner","family":"banner","dye":"light_blue"},
	650:{"name":"Brown banner","color":"79563e","block":true,"shape":"banner","family":"banner","dye":"brown"},
	651:{"name":"White bed","color":"e4e4d7","block":true,"shape":"bed","family":"bed","dye":"white"},
	652:{"name":"Grey bed","color":"626c70","block":true,"shape":"bed","family":"bed","dye":"grey"},
	653:{"name":"Light grey bed","color":"b0b4ac","block":true,"shape":"bed","family":"bed","dye":"silver"},
	654:{"name":"Black bed","color":"333740","block":true,"shape":"bed","family":"bed","dye":"black"},
	655:{"name":"Yellow bed","color":"edc647","block":true,"shape":"bed","family":"bed","dye":"yellow"},
	656:{"name":"Orange bed","color":"e4943e","block":true,"shape":"bed","family":"bed","dye":"orange"},
	657:{"name":"Red bed","color":"b83d41","block":true,"shape":"bed","family":"bed","dye":"red"},
	658:{"name":"Magenta bed","color":"b94baf","block":true,"shape":"bed","family":"bed","dye":"magenta"},
	659:{"name":"Purple bed","color":"824aaa","block":true,"shape":"bed","family":"bed","dye":"purple"},
	660:{"name":"Blue bed","color":"4966ad","block":true,"shape":"bed","family":"bed","dye":"blue"},
	661:{"name":"Cyan bed","color":"378a99","block":true,"shape":"bed","family":"bed","dye":"cyan"},
	662:{"name":"Lime bed","color":"8bbe45","block":true,"shape":"bed","family":"bed","dye":"lime"},
	663:{"name":"Green bed","color":"51763e","block":true,"shape":"bed","family":"bed","dye":"green"},
	664:{"name":"Pink bed","color":"dd8eac","block":true,"shape":"bed","family":"bed","dye":"pink"},
	665:{"name":"Light blue bed","color":"79b4d2","block":true,"shape":"bed","family":"bed","dye":"light_blue"},
	666:{"name":"Brown bed","color":"79563e","block":true,"shape":"bed","family":"bed","dye":"brown"},
	667:{"name":"White bed head","color":"e4e4d7","block":true,"shape":"bed_head","family":"bed_head","dye":"white"},
	668:{"name":"Grey bed head","color":"626c70","block":true,"shape":"bed_head","family":"bed_head","dye":"grey"},
	669:{"name":"Light grey bed head","color":"b0b4ac","block":true,"shape":"bed_head","family":"bed_head","dye":"silver"},
	670:{"name":"Black bed head","color":"333740","block":true,"shape":"bed_head","family":"bed_head","dye":"black"},
	671:{"name":"Yellow bed head","color":"edc647","block":true,"shape":"bed_head","family":"bed_head","dye":"yellow"},
	672:{"name":"Orange bed head","color":"e4943e","block":true,"shape":"bed_head","family":"bed_head","dye":"orange"},
	673:{"name":"Red bed head","color":"b83d41","block":true,"shape":"bed_head","family":"bed_head","dye":"red"},
	674:{"name":"Magenta bed head","color":"b94baf","block":true,"shape":"bed_head","family":"bed_head","dye":"magenta"},
	675:{"name":"Purple bed head","color":"824aaa","block":true,"shape":"bed_head","family":"bed_head","dye":"purple"},
	676:{"name":"Blue bed head","color":"4966ad","block":true,"shape":"bed_head","family":"bed_head","dye":"blue"},
	677:{"name":"Cyan bed head","color":"378a99","block":true,"shape":"bed_head","family":"bed_head","dye":"cyan"},
	678:{"name":"Lime bed head","color":"8bbe45","block":true,"shape":"bed_head","family":"bed_head","dye":"lime"},
	679:{"name":"Green bed head","color":"51763e","block":true,"shape":"bed_head","family":"bed_head","dye":"green"},
	680:{"name":"Pink bed head","color":"dd8eac","block":true,"shape":"bed_head","family":"bed_head","dye":"pink"},
	681:{"name":"Light blue bed head","color":"79b4d2","block":true,"shape":"bed_head","family":"bed_head","dye":"light_blue"},
	682:{"name":"Brown bed head","color":"79563e","block":true,"shape":"bed_head","family":"bed_head","dye":"brown"},
	821:{"name":"White dye","color":"e4e4d7","family":"dye","dye":"white"},
	822:{"name":"Grey dye","color":"626c70","family":"dye","dye":"grey"},
	823:{"name":"Light grey dye","color":"b0b4ac","family":"dye","dye":"silver"},
	824:{"name":"Black dye","color":"333740","family":"dye","dye":"black"},
	825:{"name":"Yellow dye","color":"edc647","family":"dye","dye":"yellow"},
	826:{"name":"Orange dye","color":"e4943e","family":"dye","dye":"orange"},
	827:{"name":"Red dye","color":"b83d41","family":"dye","dye":"red"},
	828:{"name":"Magenta dye","color":"b94baf","family":"dye","dye":"magenta"},
	829:{"name":"Purple dye","color":"824aaa","family":"dye","dye":"purple"},
	830:{"name":"Blue dye","color":"4966ad","family":"dye","dye":"blue"},
	831:{"name":"Cyan dye","color":"378a99","family":"dye","dye":"cyan"},
	832:{"name":"Lime dye","color":"8bbe45","family":"dye","dye":"lime"},
	833:{"name":"Green dye","color":"51763e","family":"dye","dye":"green"},
	834:{"name":"Pink dye","color":"dd8eac","family":"dye","dye":"pink"},
	835:{"name":"Light blue dye","color":"79b4d2","family":"dye","dye":"light_blue"},
	836:{"name":"Brown dye","color":"79563e","family":"dye","dye":"brown"},
	837:{"name":"Oak boat","color":"b7955e","stack":1,"family":"boat"},
	838:{"name":"Acacia boat","color":"ba6f4c","stack":1,"family":"boat"},
	839:{"name":"Spruce boat","color":"896744","stack":1,"family":"boat"},
	840:{"name":"Dark oak boat","color":"594336","stack":1,"family":"boat"},
	841:{"name":"Birch boat","color":"dbcf9c","stack":1,"family":"boat"},
	842:{"name":"Healing arrow","color":"f6493a","family":"arrow","stack":64,"effect":"healing"},
	843:{"name":"Harming arrow","color":"a07669","family":"arrow","stack":64,"effect":"harming"},
	844:{"name":"Night vision arrow","color":"c8f356","family":"arrow","stack":64,"effect":"night_vision"},
	845:{"name":"Swiftness arrow","color":"5ae9fe","family":"arrow","stack":64,"effect":"swiftness"},
	846:{"name":"Slowness arrow","color":"8bb3de","family":"arrow","stack":64,"effect":"slowness"},
	847:{"name":"Leaping arrow","color":"fafd8e","family":"arrow","stack":64,"effect":"leaping"},
	848:{"name":"Poison arrow","color":"86a25b","family":"arrow","stack":64,"effect":"poison"},
	849:{"name":"Regeneration arrow","color":"cb54ba","family":"arrow","stack":64,"effect":"regeneration"},
	850:{"name":"Strength arrow","color":"f8c800","family":"arrow","stack":64,"effect":"strength"},
	851:{"name":"Weakness arrow","color":"4a4e49","family":"arrow","stack":64,"effect":"weakness"},
	852:{"name":"Invisibility arrow","color":"f7fdfc","family":"arrow","stack":64,"effect":"invisibility"},
	853:{"name":"Water breathing arrow","color":"98dac1","family":"arrow","stack":64,"effect":"water_breathing"},
	854:{"name":"Fire resistance arrow","color":"fd970e","family":"arrow","stack":64,"effect":"fire_resistance"},
	855:{"name":"Healing potion","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	856:{"name":"Swiftness potion","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	857:{"name":"Fire resistance potion","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	858:{"name":"Strength potion","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	859:{"name":"Night vision potion","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	860:{"name":"Water breathing potion","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	1000:{"name":"White pouch · Level 1","color":"e4e4d7","family":"pouch","stack":1,"size":27,"level":1},
	1016:{"name":"White pouch · Level 2","color":"e4e4d7","family":"pouch","stack":1,"size":54,"level":2},
	1032:{"name":"White pouch · Level 3","color":"e4e4d7","family":"pouch","stack":1,"size":81,"level":3},
	1048:{"name":"White pouch · Level 4","color":"e4e4d7","family":"pouch","stack":1,"size":108,"level":4},
	1064:{"name":"White pouch · Level 5","color":"e4e4d7","family":"pouch","stack":1,"size":135,"level":5},
	1001:{"name":"Grey pouch · Level 1","color":"626c70","family":"pouch","stack":1,"size":27,"level":1},
	1017:{"name":"Grey pouch · Level 2","color":"626c70","family":"pouch","stack":1,"size":54,"level":2},
	1033:{"name":"Grey pouch · Level 3","color":"626c70","family":"pouch","stack":1,"size":81,"level":3},
	1049:{"name":"Grey pouch · Level 4","color":"626c70","family":"pouch","stack":1,"size":108,"level":4},
	1065:{"name":"Grey pouch · Level 5","color":"626c70","family":"pouch","stack":1,"size":135,"level":5},
	1002:{"name":"Light grey pouch · Level 1","color":"b0b4ac","family":"pouch","stack":1,"size":27,"level":1},
	1018:{"name":"Light grey pouch · Level 2","color":"b0b4ac","family":"pouch","stack":1,"size":54,"level":2},
	1034:{"name":"Light grey pouch · Level 3","color":"b0b4ac","family":"pouch","stack":1,"size":81,"level":3},
	1050:{"name":"Light grey pouch · Level 4","color":"b0b4ac","family":"pouch","stack":1,"size":108,"level":4},
	1066:{"name":"Light grey pouch · Level 5","color":"b0b4ac","family":"pouch","stack":1,"size":135,"level":5},
	1003:{"name":"Black pouch · Level 1","color":"333740","family":"pouch","stack":1,"size":27,"level":1},
	1019:{"name":"Black pouch · Level 2","color":"333740","family":"pouch","stack":1,"size":54,"level":2},
	1035:{"name":"Black pouch · Level 3","color":"333740","family":"pouch","stack":1,"size":81,"level":3},
	1051:{"name":"Black pouch · Level 4","color":"333740","family":"pouch","stack":1,"size":108,"level":4},
	1067:{"name":"Black pouch · Level 5","color":"333740","family":"pouch","stack":1,"size":135,"level":5},
	1004:{"name":"Yellow pouch · Level 1","color":"edc647","family":"pouch","stack":1,"size":27,"level":1},
	1020:{"name":"Yellow pouch · Level 2","color":"edc647","family":"pouch","stack":1,"size":54,"level":2},
	1036:{"name":"Yellow pouch · Level 3","color":"edc647","family":"pouch","stack":1,"size":81,"level":3},
	1052:{"name":"Yellow pouch · Level 4","color":"edc647","family":"pouch","stack":1,"size":108,"level":4},
	1068:{"name":"Yellow pouch · Level 5","color":"edc647","family":"pouch","stack":1,"size":135,"level":5},
	1005:{"name":"Orange pouch · Level 1","color":"e4943e","family":"pouch","stack":1,"size":27,"level":1},
	1021:{"name":"Orange pouch · Level 2","color":"e4943e","family":"pouch","stack":1,"size":54,"level":2},
	1037:{"name":"Orange pouch · Level 3","color":"e4943e","family":"pouch","stack":1,"size":81,"level":3},
	1053:{"name":"Orange pouch · Level 4","color":"e4943e","family":"pouch","stack":1,"size":108,"level":4},
	1069:{"name":"Orange pouch · Level 5","color":"e4943e","family":"pouch","stack":1,"size":135,"level":5},
	1006:{"name":"Red pouch · Level 1","color":"b83d41","family":"pouch","stack":1,"size":27,"level":1},
	1022:{"name":"Red pouch · Level 2","color":"b83d41","family":"pouch","stack":1,"size":54,"level":2},
	1038:{"name":"Red pouch · Level 3","color":"b83d41","family":"pouch","stack":1,"size":81,"level":3},
	1054:{"name":"Red pouch · Level 4","color":"b83d41","family":"pouch","stack":1,"size":108,"level":4},
	1070:{"name":"Red pouch · Level 5","color":"b83d41","family":"pouch","stack":1,"size":135,"level":5},
	1007:{"name":"Magenta pouch · Level 1","color":"b94baf","family":"pouch","stack":1,"size":27,"level":1},
	1023:{"name":"Magenta pouch · Level 2","color":"b94baf","family":"pouch","stack":1,"size":54,"level":2},
	1039:{"name":"Magenta pouch · Level 3","color":"b94baf","family":"pouch","stack":1,"size":81,"level":3},
	1055:{"name":"Magenta pouch · Level 4","color":"b94baf","family":"pouch","stack":1,"size":108,"level":4},
	1071:{"name":"Magenta pouch · Level 5","color":"b94baf","family":"pouch","stack":1,"size":135,"level":5},
	1008:{"name":"Purple pouch · Level 1","color":"824aaa","family":"pouch","stack":1,"size":27,"level":1},
	1024:{"name":"Purple pouch · Level 2","color":"824aaa","family":"pouch","stack":1,"size":54,"level":2},
	1040:{"name":"Purple pouch · Level 3","color":"824aaa","family":"pouch","stack":1,"size":81,"level":3},
	1056:{"name":"Purple pouch · Level 4","color":"824aaa","family":"pouch","stack":1,"size":108,"level":4},
	1072:{"name":"Purple pouch · Level 5","color":"824aaa","family":"pouch","stack":1,"size":135,"level":5},
	1009:{"name":"Blue pouch · Level 1","color":"4966ad","family":"pouch","stack":1,"size":27,"level":1},
	1025:{"name":"Blue pouch · Level 2","color":"4966ad","family":"pouch","stack":1,"size":54,"level":2},
	1041:{"name":"Blue pouch · Level 3","color":"4966ad","family":"pouch","stack":1,"size":81,"level":3},
	1057:{"name":"Blue pouch · Level 4","color":"4966ad","family":"pouch","stack":1,"size":108,"level":4},
	1073:{"name":"Blue pouch · Level 5","color":"4966ad","family":"pouch","stack":1,"size":135,"level":5},
	1010:{"name":"Cyan pouch · Level 1","color":"378a99","family":"pouch","stack":1,"size":27,"level":1},
	1026:{"name":"Cyan pouch · Level 2","color":"378a99","family":"pouch","stack":1,"size":54,"level":2},
	1042:{"name":"Cyan pouch · Level 3","color":"378a99","family":"pouch","stack":1,"size":81,"level":3},
	1058:{"name":"Cyan pouch · Level 4","color":"378a99","family":"pouch","stack":1,"size":108,"level":4},
	1074:{"name":"Cyan pouch · Level 5","color":"378a99","family":"pouch","stack":1,"size":135,"level":5},
	1011:{"name":"Lime pouch · Level 1","color":"8bbe45","family":"pouch","stack":1,"size":27,"level":1},
	1027:{"name":"Lime pouch · Level 2","color":"8bbe45","family":"pouch","stack":1,"size":54,"level":2},
	1043:{"name":"Lime pouch · Level 3","color":"8bbe45","family":"pouch","stack":1,"size":81,"level":3},
	1059:{"name":"Lime pouch · Level 4","color":"8bbe45","family":"pouch","stack":1,"size":108,"level":4},
	1075:{"name":"Lime pouch · Level 5","color":"8bbe45","family":"pouch","stack":1,"size":135,"level":5},
	1012:{"name":"Green pouch · Level 1","color":"51763e","family":"pouch","stack":1,"size":27,"level":1},
	1028:{"name":"Green pouch · Level 2","color":"51763e","family":"pouch","stack":1,"size":54,"level":2},
	1044:{"name":"Green pouch · Level 3","color":"51763e","family":"pouch","stack":1,"size":81,"level":3},
	1060:{"name":"Green pouch · Level 4","color":"51763e","family":"pouch","stack":1,"size":108,"level":4},
	1076:{"name":"Green pouch · Level 5","color":"51763e","family":"pouch","stack":1,"size":135,"level":5},
	1013:{"name":"Pink pouch · Level 1","color":"dd8eac","family":"pouch","stack":1,"size":27,"level":1},
	1029:{"name":"Pink pouch · Level 2","color":"dd8eac","family":"pouch","stack":1,"size":54,"level":2},
	1045:{"name":"Pink pouch · Level 3","color":"dd8eac","family":"pouch","stack":1,"size":81,"level":3},
	1061:{"name":"Pink pouch · Level 4","color":"dd8eac","family":"pouch","stack":1,"size":108,"level":4},
	1077:{"name":"Pink pouch · Level 5","color":"dd8eac","family":"pouch","stack":1,"size":135,"level":5},
	1014:{"name":"Light blue pouch · Level 1","color":"79b4d2","family":"pouch","stack":1,"size":27,"level":1},
	1030:{"name":"Light blue pouch · Level 2","color":"79b4d2","family":"pouch","stack":1,"size":54,"level":2},
	1046:{"name":"Light blue pouch · Level 3","color":"79b4d2","family":"pouch","stack":1,"size":81,"level":3},
	1062:{"name":"Light blue pouch · Level 4","color":"79b4d2","family":"pouch","stack":1,"size":108,"level":4},
	1078:{"name":"Light blue pouch · Level 5","color":"79b4d2","family":"pouch","stack":1,"size":135,"level":5},
	1015:{"name":"Brown pouch · Level 1","color":"79563e","family":"pouch","stack":1,"size":27,"level":1},
	1031:{"name":"Brown pouch · Level 2","color":"79563e","family":"pouch","stack":1,"size":54,"level":2},
	1047:{"name":"Brown pouch · Level 3","color":"79563e","family":"pouch","stack":1,"size":81,"level":3},
	1063:{"name":"Brown pouch · Level 4","color":"79563e","family":"pouch","stack":1,"size":108,"level":4},
	1079:{"name":"Brown pouch · Level 5","color":"79563e","family":"pouch","stack":1,"size":135,"level":5},
	2048:{"name":"Water splash","color":"8091ff","family":"potion","stack":1,"effect":"water"},
	2049:{"name":"Water lingering","color":"8091ff","family":"potion","stack":1,"effect":"water"},
	2050:{"name":"Awkward potion","color":"8091ff","family":"potion","stack":1,"effect":"awkward"},
	2051:{"name":"Awkward splash","color":"8091ff","family":"potion","stack":1,"effect":"awkward"},
	2052:{"name":"Awkward lingering","color":"8091ff","family":"potion","stack":1,"effect":"awkward"},
	2053:{"name":"Mundane potion","color":"8091ff","family":"potion","stack":1,"effect":"mundane"},
	2054:{"name":"Mundane splash","color":"8091ff","family":"potion","stack":1,"effect":"mundane"},
	2055:{"name":"Mundane lingering","color":"8091ff","family":"potion","stack":1,"effect":"mundane"},
	2056:{"name":"Thick potion","color":"8091ff","family":"potion","stack":1,"effect":"thick"},
	2057:{"name":"Thick splash","color":"8091ff","family":"potion","stack":1,"effect":"thick"},
	2058:{"name":"Thick lingering","color":"8091ff","family":"potion","stack":1,"effect":"thick"},
	2059:{"name":"Healing potion II","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	2060:{"name":"Healing splash","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	2061:{"name":"Healing splash II","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	2062:{"name":"Healing lingering","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	2063:{"name":"Healing lingering II","color":"f6493a","family":"potion","stack":1,"effect":"healing"},
	2064:{"name":"Healing arrow II","color":"f6493a","family":"arrow","stack":64,"effect":"healing"},
	2065:{"name":"Harming potion","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2066:{"name":"Harming potion II","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2067:{"name":"Harming splash","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2068:{"name":"Harming splash II","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2069:{"name":"Harming lingering","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2070:{"name":"Harming lingering II","color":"a07669","family":"potion","stack":1,"effect":"harming"},
	2071:{"name":"Harming arrow II","color":"a07669","family":"arrow","stack":64,"effect":"harming"},
	2072:{"name":"Night vision potion (extended)","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	2073:{"name":"Night vision splash","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	2074:{"name":"Night vision splash (extended)","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	2075:{"name":"Night vision lingering","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	2076:{"name":"Night vision lingering (extended)","color":"c8f356","family":"potion","stack":1,"effect":"night_vision"},
	2077:{"name":"Night vision arrow (extended)","color":"c8f356","family":"arrow","stack":64,"effect":"night_vision"},
	2078:{"name":"Swiftness potion (extended)","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2079:{"name":"Swiftness potion II","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2080:{"name":"Swiftness splash","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2081:{"name":"Swiftness splash (extended)","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2082:{"name":"Swiftness splash II","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2083:{"name":"Swiftness lingering","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2084:{"name":"Swiftness lingering (extended)","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2085:{"name":"Swiftness lingering II","color":"5ae9fe","family":"potion","stack":1,"effect":"swiftness"},
	2086:{"name":"Swiftness arrow (extended)","color":"5ae9fe","family":"arrow","stack":64,"effect":"swiftness"},
	2087:{"name":"Swiftness arrow II","color":"5ae9fe","family":"arrow","stack":64,"effect":"swiftness"},
	2088:{"name":"Slowness potion","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2089:{"name":"Slowness potion (extended)","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2090:{"name":"Slowness potion IV","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2091:{"name":"Slowness splash","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2092:{"name":"Slowness splash (extended)","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2093:{"name":"Slowness splash IV","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2094:{"name":"Slowness lingering","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2095:{"name":"Slowness lingering (extended)","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2096:{"name":"Slowness lingering IV","color":"8bb3de","family":"potion","stack":1,"effect":"slowness"},
	2097:{"name":"Slowness arrow (extended)","color":"8bb3de","family":"arrow","stack":64,"effect":"slowness"},
	2098:{"name":"Slowness arrow IV","color":"8bb3de","family":"arrow","stack":64,"effect":"slowness"},
	2099:{"name":"Leaping potion","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2100:{"name":"Leaping potion (extended)","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2101:{"name":"Leaping potion II","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2102:{"name":"Leaping splash","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2103:{"name":"Leaping splash (extended)","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2104:{"name":"Leaping splash II","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2105:{"name":"Leaping lingering","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2106:{"name":"Leaping lingering (extended)","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2107:{"name":"Leaping lingering II","color":"fafd8e","family":"potion","stack":1,"effect":"leaping"},
	2108:{"name":"Leaping arrow (extended)","color":"fafd8e","family":"arrow","stack":64,"effect":"leaping"},
	2109:{"name":"Leaping arrow II","color":"fafd8e","family":"arrow","stack":64,"effect":"leaping"},
	2110:{"name":"Withering potion","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2111:{"name":"Withering potion (extended)","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2112:{"name":"Withering potion II","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2113:{"name":"Withering splash","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2114:{"name":"Withering splash (extended)","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2115:{"name":"Withering splash II","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2116:{"name":"Withering lingering","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2117:{"name":"Withering lingering (extended)","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2118:{"name":"Withering lingering II","color":"6d5c50","family":"potion","stack":1,"effect":"withering"},
	2119:{"name":"Withering arrow","color":"6d5c50","family":"arrow","stack":64,"effect":"withering"},
	2120:{"name":"Withering arrow (extended)","color":"6d5c50","family":"arrow","stack":64,"effect":"withering"},
	2121:{"name":"Withering arrow II","color":"6d5c50","family":"arrow","stack":64,"effect":"withering"},
	2122:{"name":"Poison potion","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2123:{"name":"Poison potion (extended)","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2124:{"name":"Poison potion II","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2125:{"name":"Poison splash","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2126:{"name":"Poison splash (extended)","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2127:{"name":"Poison splash II","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2128:{"name":"Poison lingering","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2129:{"name":"Poison lingering (extended)","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2130:{"name":"Poison lingering II","color":"86a25b","family":"potion","stack":1,"effect":"poison"},
	2131:{"name":"Poison arrow (extended)","color":"86a25b","family":"arrow","stack":64,"effect":"poison"},
	2132:{"name":"Poison arrow II","color":"86a25b","family":"arrow","stack":64,"effect":"poison"},
	2133:{"name":"Regeneration potion","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2134:{"name":"Regeneration potion (extended)","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2135:{"name":"Regeneration potion II","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2136:{"name":"Regeneration splash","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2137:{"name":"Regeneration splash (extended)","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2138:{"name":"Regeneration splash II","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2139:{"name":"Regeneration lingering","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2140:{"name":"Regeneration lingering (extended)","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2141:{"name":"Regeneration lingering II","color":"cb54ba","family":"potion","stack":1,"effect":"regeneration"},
	2142:{"name":"Regeneration arrow (extended)","color":"cb54ba","family":"arrow","stack":64,"effect":"regeneration"},
	2143:{"name":"Regeneration arrow II","color":"cb54ba","family":"arrow","stack":64,"effect":"regeneration"},
	2144:{"name":"Invisibility potion","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2145:{"name":"Invisibility potion (extended)","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2146:{"name":"Invisibility splash","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2147:{"name":"Invisibility splash (extended)","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2148:{"name":"Invisibility lingering","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2149:{"name":"Invisibility lingering (extended)","color":"f7fdfc","family":"potion","stack":1,"effect":"invisibility"},
	2150:{"name":"Invisibility arrow (extended)","color":"f7fdfc","family":"arrow","stack":64,"effect":"invisibility"},
	2151:{"name":"Water breathing potion (extended)","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	2152:{"name":"Water breathing splash","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	2153:{"name":"Water breathing splash (extended)","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	2154:{"name":"Water breathing lingering","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	2155:{"name":"Water breathing lingering (extended)","color":"98dac1","family":"potion","stack":1,"effect":"water_breathing"},
	2156:{"name":"Water breathing arrow (extended)","color":"98dac1","family":"arrow","stack":64,"effect":"water_breathing"},
	2157:{"name":"Fire resistance potion (extended)","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	2158:{"name":"Fire resistance splash","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	2159:{"name":"Fire resistance splash (extended)","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	2160:{"name":"Fire resistance lingering","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	2161:{"name":"Fire resistance lingering (extended)","color":"fd970e","family":"potion","stack":1,"effect":"fire_resistance"},
	2162:{"name":"Fire resistance arrow (extended)","color":"fd970e","family":"arrow","stack":64,"effect":"fire_resistance"},
	2163:{"name":"Strength potion (extended)","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2164:{"name":"Strength potion II","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2165:{"name":"Strength splash","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2166:{"name":"Strength splash (extended)","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2167:{"name":"Strength splash II","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2168:{"name":"Strength lingering","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2169:{"name":"Strength lingering (extended)","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2170:{"name":"Strength lingering II","color":"f8c800","family":"potion","stack":1,"effect":"strength"},
	2171:{"name":"Strength arrow (extended)","color":"f8c800","family":"arrow","stack":64,"effect":"strength"},
	2172:{"name":"Strength arrow II","color":"f8c800","family":"arrow","stack":64,"effect":"strength"},
	2173:{"name":"Weakness potion","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2174:{"name":"Weakness potion (extended)","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2175:{"name":"Weakness potion II","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2176:{"name":"Weakness splash","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2177:{"name":"Weakness splash (extended)","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2178:{"name":"Weakness splash II","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2179:{"name":"Weakness lingering","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2180:{"name":"Weakness lingering (extended)","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2181:{"name":"Weakness lingering II","color":"4a4e49","family":"potion","stack":1,"effect":"weakness"},
	2182:{"name":"Weakness arrow (extended)","color":"4a4e49","family":"arrow","stack":64,"effect":"weakness"},
	2183:{"name":"Weakness arrow II","color":"4a4e49","family":"arrow","stack":64,"effect":"weakness"},
	2184:{"name":"Slow falling potion","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2185:{"name":"Slow falling potion (extended)","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2186:{"name":"Slow falling splash","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2187:{"name":"Slow falling splash (extended)","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2188:{"name":"Slow falling lingering","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2189:{"name":"Slow falling lingering (extended)","color":"eed1ba","family":"potion","stack":1,"effect":"slow_falling"},
	2190:{"name":"Slow falling arrow","color":"eed1ba","family":"arrow","stack":64,"effect":"slow_falling"},
	2191:{"name":"Slow falling arrow (extended)","color":"eed1ba","family":"arrow","stack":64,"effect":"slow_falling"},
	2192:{"name":"Turtle master potion","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2193:{"name":"Turtle master potion (extended)","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2194:{"name":"Turtle master potion II","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2195:{"name":"Turtle master splash","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2196:{"name":"Turtle master splash (extended)","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2197:{"name":"Turtle master splash II","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2198:{"name":"Turtle master lingering","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2199:{"name":"Turtle master lingering (extended)","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2200:{"name":"Turtle master lingering II","color":"8473dd","family":"potion","stack":1,"effect":"turtle_master"},
	2201:{"name":"Turtle master arrow","color":"8473dd","family":"arrow","stack":64,"effect":"turtle_master"},
	2202:{"name":"Turtle master arrow (extended)","color":"8473dd","family":"arrow","stack":64,"effect":"turtle_master"},
	2203:{"name":"Turtle master arrow II","color":"8473dd","family":"arrow","stack":64,"effect":"turtle_master"},
	2204:{"name":"Luck potion","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2205:{"name":"Luck potion (extended)","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2206:{"name":"Luck potion II","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2207:{"name":"Luck splash","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2208:{"name":"Luck splash (extended)","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2209:{"name":"Luck splash II","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2210:{"name":"Luck lingering","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2211:{"name":"Luck lingering (extended)","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2212:{"name":"Luck lingering II","color":"59c500","family":"potion","stack":1,"effect":"luck"},
	2213:{"name":"Luck arrow","color":"59c500","family":"arrow","stack":64,"effect":"luck"},
	2214:{"name":"Luck arrow (extended)","color":"59c500","family":"arrow","stack":64,"effect":"luck"},
	2215:{"name":"Luck arrow II","color":"59c500","family":"arrow","stack":64,"effect":"luck"},
	2216:{"name":"Bad luck potion","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2217:{"name":"Bad luck potion (extended)","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2218:{"name":"Bad luck potion II","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2219:{"name":"Bad luck splash","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2220:{"name":"Bad luck splash (extended)","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2221:{"name":"Bad luck splash II","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2222:{"name":"Bad luck lingering","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2223:{"name":"Bad luck lingering (extended)","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2224:{"name":"Bad luck lingering II","color":"c9aa56","family":"potion","stack":1,"effect":"bad_luck"},
	2225:{"name":"Bad luck arrow","color":"c9aa56","family":"arrow","stack":64,"effect":"bad_luck"},
	2226:{"name":"Bad luck arrow (extended)","color":"c9aa56","family":"arrow","stack":64,"effect":"bad_luck"},
	2227:{"name":"Bad luck arrow II","color":"c9aa56","family":"arrow","stack":64,"effect":"bad_luck"},
	2228:{"name":"Ominous bottle","color":"325749","family":"potion","stack":1,"effect":"bad_omen"},
	2229:{"name":"Ominous bottle II","color":"325749","family":"potion","stack":1,"effect":"bad_omen"},
	2230:{"name":"Infestation potion","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2231:{"name":"Infestation potion (extended)","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2232:{"name":"Infestation splash","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2233:{"name":"Infestation splash (extended)","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2234:{"name":"Infestation lingering","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2235:{"name":"Infestation lingering (extended)","color":"899b8a","family":"potion","stack":1,"effect":"infested"},
	2236:{"name":"Infestation arrow","color":"899b8a","family":"arrow","stack":64,"effect":"infested"},
	2237:{"name":"Infestation arrow (extended)","color":"899b8a","family":"arrow","stack":64,"effect":"infested"},
	2238:{"name":"Oozing potion","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2239:{"name":"Oozing potion (extended)","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2240:{"name":"Oozing splash","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2241:{"name":"Oozing splash (extended)","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2242:{"name":"Oozing lingering","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2243:{"name":"Oozing lingering (extended)","color":"a5fda9","family":"potion","stack":1,"effect":"oozing"},
	2244:{"name":"Oozing arrow","color":"a5fda9","family":"arrow","stack":64,"effect":"oozing"},
	2245:{"name":"Oozing arrow (extended)","color":"a5fda9","family":"arrow","stack":64,"effect":"oozing"},
	2246:{"name":"Weaving potion","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2247:{"name":"Weaving potion (extended)","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2248:{"name":"Weaving splash","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2249:{"name":"Weaving splash (extended)","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2250:{"name":"Weaving lingering","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2251:{"name":"Weaving lingering (extended)","color":"75675a","family":"potion","stack":1,"effect":"weaving"},
	2252:{"name":"Weaving arrow","color":"75675a","family":"arrow","stack":64,"effect":"weaving"},
	2253:{"name":"Weaving arrow (extended)","color":"75675a","family":"arrow","stack":64,"effect":"weaving"},
	2254:{"name":"Wind charged potion","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2255:{"name":"Wind charged potion (extended)","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2256:{"name":"Wind charged splash","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2257:{"name":"Wind charged splash (extended)","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2258:{"name":"Wind charged lingering","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2259:{"name":"Wind charged lingering (extended)","color":"bcc8ff","family":"potion","stack":1,"effect":"wind_charged"},
	2260:{"name":"Wind charged arrow","color":"bcc8ff","family":"arrow","stack":64,"effect":"wind_charged"},
	2261:{"name":"Wind charged arrow (extended)","color":"bcc8ff","family":"arrow","stack":64,"effect":"wind_charged"},
	940:{"name":"Fermented spider eye","color":"a2604f"},
	941:{"name":"Glowstone dust","color":"eec47a"},
	942:{"name":"Dragon breath","color":"c877dc","stack":64,"family":"potion_ingredient"},
	943:{"name":"Phantom membrane","color":"aeb5ae"},
	944:{"name":"Breeze rod","color":"b5cedc"},
	945:{"name":"Turtle scute","color":"70aa71"},
	946:{"name":"Trident","color":"69bab5","stack":1,"durability":250},
	947:{"name":"Mace","color":"849696","stack":1,"durability":500},
	948:{"name":"Heavy core","color":"737d84"},
	949:{"name":"Turtle shell","color":"5c9672","stack":1,"durability":275,"armor":"helmet"},
	689:{"name":"Slime block","color":"81ba65","block":true},
	690:{"name":"Cobweb","color":"d3d8d1","block":true,"shape":"plant"},
	692:{"name":"Recovery chest","color":"90734d","block":true,"tool":1},
	691:{"name":"Frosted ice","color":"b2dbed","block":true},
}

const PROFESSIONS = ["farmer","fisherman","fletcher","shepherd","librarian","cartographer","armorer","leatherworker","butcher","weaponsmith","toolsmith","cleric","mason"]
const JOBS = [COMPOSTER,BARREL,FLETCHING_TABLE,LOOM,LECTERN,CARTOGRAPHY_TABLE,BLAST_FURNACE,CAULDRON,SMOKER,GRINDSTONE,SMITHING_TABLE,BREWING_STAND,STONECUTTER]
const LEVELS = [0,10,70,150,250]
const RANKS = ["Novice","Apprentice","Journeyman","Expert","Master"]
const CROPS = {CARROT:CARROTS_0,POTATO:POTATOES_0,BEETROOT_SEEDS:BEETROOTS_0,NETHER_WART_ITEM:NETHER_WART_0,SWEET_BERRY:SWEET_BERRIES_0}

static func shape(id: int) -> String:
	return DATA.get(id,{}).get("shape","cube")

static func is_bed(id: int) -> bool:
	return id in [Nodes.BED_FOOT,Nodes.BED_HEAD] or shape(id) in ["bed","bed_head"]

static func bed_foot(id: int) -> int:
	if id in [Nodes.BED_FOOT,Nodes.BED_HEAD]: return Nodes.BED_FOOT
	return id-16 if shape(id) == "bed_head" else id

static func bed_head(id: int) -> int:
	return Nodes.BED_HEAD if id in [Nodes.BED_FOOT,Nodes.BED_HEAD] else bed_foot(id)+16

static func crop_seed(id: int) -> int:
	if CropFarming.is_crop(id): return CropFarming.seed_item(id)
	for seed_id in CROPS:
		if id >= CROPS[seed_id] and id <= CROPS[seed_id]+3: return seed_id
	return 0

static func crop_drops(id: int) -> Array:
	if CropFarming.is_crop(id): return CropFarming.harvest(id)
	var seed_id: int = crop_seed(id)
	if id == COCOA_POD: return [[COCOA_BEANS,1]]
	if id == RIPE_COCOA_POD: return [[COCOA_BEANS,3]]
	if id == KELP_PLANT: return [[KELP,1]]
	if seed_id == 0: return []
	if DATA[id].stage < 3: return [[seed_id,1]]
	return [[BEETROOT,1],[BEETROOT_SEEDS,2]] if seed_id == BEETROOT_SEEDS else [[seed_id,3]]

static func special(id: int) -> bool:
	return DATA.has(id) and DATA[id].get("block",false) and shape(id) not in ["cube","crop","plant","vine"]

static func recipes(inv: Inventory) -> void:
	inv._recipe("Leads",LEAD,2,[Nodes.STRING,Nodes.STRING,0,Nodes.STRING,Nodes.SLIME_BALL,0,0,0,Nodes.STRING],3,"table")
	# Clock and compass, from mcl_clock and mcl_compass: four gold plus redstone,
	# and four iron plus redstone.
	inv._recipe("Clock",Nodes.CLOCK,1,[0,Nodes.GOLD,0,Nodes.GOLD,Nodes.REDSTONE_WIRE,Nodes.GOLD,0,Nodes.GOLD,0],3,"table")
	inv._recipe("Compass",Nodes.COMPASS,1,[0,Nodes.IRON,0,Nodes.IRON,Nodes.REDSTONE_WIRE,Nodes.IRON,0,Nodes.IRON,0],3,"table")
	var p: int = Nodes.PLANKS; var iron: int = Nodes.IRON
	var defs: Dictionary = {
		BLAST_FURNACE:[iron,iron,iron,iron,Nodes.FURNACE,iron,Nodes.STONE,Nodes.STONE,Nodes.STONE],
		SMOKER:[0,Nodes.LOG,0,Nodes.LOG,Nodes.FURNACE,Nodes.LOG,0,Nodes.LOG,0],
		BARREL:[p,0,p,p,0,p,p,p,p],
		CARTOGRAPHY_TABLE:[Nodes.PAPER,Nodes.PAPER,0,p,p,0,p,p,0],
		FLETCHING_TABLE:[Nodes.FLINT,Nodes.FLINT,0,p,p,0,p,p,0],
		SMITHING_TABLE:[iron,iron,0,p,p,0,p,p,0],
		LOOM:[Nodes.STRING,Nodes.STRING,0,p,p,0,0,0,0],
		LECTERN:[p,p,p,0,Nodes.BOOKSHELF,0,0,p,0],
		BREWING_STAND:[0,Nodes.BLAZE_ROD,0,Nodes.COBBLE,Nodes.COBBLE,Nodes.COBBLE,0,0,0],
		CAULDRON:[iron,0,iron,iron,0,iron,iron,iron,iron],
		STONECUTTER:[0,iron,0,Nodes.STONE,Nodes.STONE,Nodes.STONE,0,0,0],
		GRINDSTONE:[Nodes.STICK,Nodes.STONE,Nodes.STICK,p,0,p,0,0,0],
		ANVIL:[Nodes.IRON_BLOCK,Nodes.IRON_BLOCK,Nodes.IRON_BLOCK,0,iron,0,iron,iron,iron],
		BELL:[0,Nodes.GOLD_BLOCK,0,Nodes.COBBLE,Nodes.GOLD,Nodes.COBBLE,0,0,0],
		LANTERN:[Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.TORCH,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET],
		# `mcl_lanterns`: the same ring around a soul torch, and a chain of
		# nugget-ingot-nugget.
		SOUL_LANTERN:[Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.SOUL_TORCH,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET],
		CHAIN:[Nodes.IRON_NUGGET,Nodes.IRON,Nodes.IRON_NUGGET],
		FISHING_ROD:[0,0,Nodes.STICK,0,Nodes.STICK,Nodes.STRING,Nodes.STICK,0,Nodes.STRING],
		CROSSBOW:[Nodes.STICK,iron,Nodes.STICK,Nodes.STRING,Nodes.BOW,Nodes.STRING,0,Nodes.STICK,0],
		SHIELD:[p,iron,p,p,p,p,0,p,0],
		EMERALD_BLOCK:[EMERALD,EMERALD,EMERALD,EMERALD,EMERALD,EMERALD,EMERALD,EMERALD,EMERALD],
		GOLDEN_CARROT:[Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,CARROT,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET],
		GLISTERING_MELON:[Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.MELON_SLICE,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET],
		CAKE:[Nodes.MILK_BUCKET,Nodes.MILK_BUCKET,Nodes.MILK_BUCKET,Nodes.SUGAR,Nodes.EGG,Nodes.SUGAR,Nodes.GRAIN,Nodes.GRAIN,Nodes.GRAIN],
		EMPTY_MAP:[Nodes.PAPER,Nodes.PAPER,Nodes.PAPER,Nodes.PAPER,Nodes.COMPASS,Nodes.PAPER,Nodes.PAPER,Nodes.PAPER,Nodes.PAPER],
		ITEM_FRAME:[Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.LEATHER,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK],
		PAINTING:[Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.WOOL,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK],
	}
	for id in defs: inv._recipe(Nodes.title(id),id,1,defs[id],3,"table")
	Composters.recipes(inv)
	inv._recipe("Leather from rabbit hides",Nodes.LEATHER,1,[RABBIT_HIDE,RABBIT_HIDE,RABBIT_HIDE,RABBIT_HIDE],2)
	inv._recipe("Leather horse armor",LEATHER_HORSE_ARMOR,1,[Nodes.LEATHER,0,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,0,Nodes.LEATHER],3,"table")
	inv._recipe("Emeralds",EMERALD,9,[EMERALD_BLOCK],1)
	inv._recipe("Glass bottles",GLASS_BOTTLE,3,[Nodes.GLASS,0,Nodes.GLASS,0,Nodes.GLASS,0],3,"table")
	inv._recipe("Glass panes",GLASS_PANE,16,[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS],3,"table")
	inv._recipe("Wooden doors",WOODEN_DOOR,3,[p,p,p,p,p,p],2,"table")
	inv._recipe("Cookies",COOKIE,8,[Nodes.GRAIN,COCOA_BEANS,Nodes.GRAIN],3,"table")
	inv._shapeless("Rabbit stew",RABBIT_STEW,1,[Nodes.BOWL,COOKED_RABBIT,CARROT,BAKED_POTATO,Nodes.BROWN_MUSHROOM])
	inv._recipe("Dried kelp block",DRIED_KELP_BLOCK,1,[DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP],3,"table")
	inv._recipe("Dried kelp",DRIED_KELP,9,[DRIED_KELP_BLOCK],1)
	inv._recipe("Quartz block",QUARTZ_BLOCK,1,[Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ],2)
	for pair in [[GRANITE,POLISHED_GRANITE],[ANDESITE,POLISHED_ANDESITE],[DIORITE,POLISHED_DIORITE]]: inv._recipe(Nodes.title(pair[1]),pair[1],4,[pair[0],pair[0],pair[0],pair[0]],2)
	Magma.recipes(inv)
	LushCaves.recipes(inv)
	Concrete.recipes(inv)
	Candles.recipes(inv)
	NetherBlocks.recipes(inv)
	ArmorTrims.recipes(inv)
	EndMud.recipes(inv)
	FlowersExtra.recipes(inv)
	Sculk.recipes(inv)
	PaleOak.recipes(inv)
	CopperDecor.recipes(inv)
	Bookshelves.recipes(inv)
	NetherBlocks.recipes(inv)
	RawOres.recipes(inv)
	GlassColors.recipes(inv)
	TrappedChests.recipes(inv)
	for pair in [[Nodes.FLOWER,DYE_RED],[Nodes.BONE_MEAL,DYE_WHITE],[INK_SAC,DYE_BLACK],[Nodes.LAPIS,DYE_BLUE],[COCOA_BEANS,DYE_BROWN],[Nodes.CACTUS,DYE_GREEN]]: inv._recipe(Nodes.title(pair[1]),pair[1],1,[pair[0]],1)
	for mix in [[DYE_RED,DYE_YELLOW,DYE_ORANGE],[DYE_RED,DYE_WHITE,DYE_PINK],[DYE_BLUE,DYE_WHITE,DYE_LIGHT_BLUE],[DYE_BLUE,DYE_RED,DYE_PURPLE],[DYE_GREEN,DYE_WHITE,DYE_LIME],[DYE_BLUE,DYE_GREEN,DYE_CYAN],[DYE_BLACK,DYE_WHITE,DYE_GREY],[DYE_GREY,DYE_WHITE,DYE_SILVER],[DYE_PURPLE,DYE_PINK,DYE_MAGENTA]]: inv._shapeless(Nodes.title(mix[2]),mix[2],2,[mix[0],mix[1]])
	for id in DATA:
		var d: Dictionary = DATA[id]; var family: String = d.get("family","")
		if family not in ["wool","carpet","bed","banner","terracotta"]: continue
		var color_index: int = id-(WOOL_WHITE if family == "wool" else (CARPET_WHITE if family == "carpet" else (BED_WHITE if family == "bed" else (BANNER_WHITE if family == "banner" else TERRACOTTA_WHITE))))
		var dye: int = DYE_WHITE+color_index; var wool: int = WOOL_WHITE+color_index
		if family == "wool": inv._shapeless(Nodes.title(id),id,1,[Nodes.WOOL,dye])
		if family == "carpet": inv._recipe(Nodes.title(id),id,3,[wool,wool],2)
		if family == "bed": inv._recipe(Nodes.title(id),id,1,[wool,wool,wool,p,p,p],3,"table")
		if family == "banner": inv._recipe(Nodes.title(id),id,1,[wool,wool,wool,wool,wool,wool,0,Nodes.STICK,0],3,"table")
		if family == "terracotta": inv._shapeless(Nodes.title(id),id,1,[Nodes.TERRACOTTA,dye])
