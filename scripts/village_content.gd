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
const BLOCKS = [512, 513, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526, 527, 528, 529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549, 550, 551, 552, 553, 554, 555, 556, 557, 558, 559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 598, 599, 600, 601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 611, 612, 613, 614, 615, 616, 617, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 660, 661, 662, 663, 664, 665, 666, 667, 668, 669, 670, 671, 672, 673, 674, 675, 676, 677, 678, 679, 680, 681, 682, 683, 684, 685, 686, 687, 688, 689, 690, 691, 692]
const DATA = {
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
	519:{"name":"Composter","color":"937043","block":true,"tool":1},
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
	531:{"name":"Campfire","color":"b57843","block":true,"shape":"campfire"},
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
	551:{"name":"Carrots (growing)","color":"ed9449","block":true,"shape":"crop","crop":"carrots","stage":0,"tool":-1},
	552:{"name":"Carrots (growing)","color":"ed9449","block":true,"shape":"crop","crop":"carrots","stage":1,"tool":-1},
	553:{"name":"Carrots (growing)","color":"ed9449","block":true,"shape":"crop","crop":"carrots","stage":2,"tool":-1},
	554:{"name":"Carrots (ripe)","color":"ed9449","block":true,"shape":"crop","crop":"carrots","stage":3,"tool":-1},
	555:{"name":"Potatoes (growing)","color":"b99860","block":true,"shape":"crop","crop":"potatoes","stage":0,"tool":-1},
	556:{"name":"Potatoes (growing)","color":"b99860","block":true,"shape":"crop","crop":"potatoes","stage":1,"tool":-1},
	557:{"name":"Potatoes (growing)","color":"b99860","block":true,"shape":"crop","crop":"potatoes","stage":2,"tool":-1},
	558:{"name":"Potatoes (ripe)","color":"b99860","block":true,"shape":"crop","crop":"potatoes","stage":3,"tool":-1},
	559:{"name":"Beetroots (growing)","color":"a5445a","block":true,"shape":"crop","crop":"beetroots","stage":0,"tool":-1},
	560:{"name":"Beetroots (growing)","color":"a5445a","block":true,"shape":"crop","crop":"beetroots","stage":1,"tool":-1},
	561:{"name":"Beetroots (growing)","color":"a5445a","block":true,"shape":"crop","crop":"beetroots","stage":2,"tool":-1},
	562:{"name":"Beetroots (ripe)","color":"a5445a","block":true,"shape":"crop","crop":"beetroots","stage":3,"tool":-1},
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
	779:{"name":"Cake","color":"efdbc1","food":14},
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
	for seed_id in CROPS:
		if id >= CROPS[seed_id] and id <= CROPS[seed_id]+3: return seed_id
	return 0

static func crop_drops(id: int) -> Array:
	var seed_id: int = crop_seed(id)
	if id == COCOA_POD: return [[COCOA_BEANS,1]]
	if id == RIPE_COCOA_POD: return [[COCOA_BEANS,3]]
	if id == KELP_PLANT: return [[KELP,1]]
	if seed_id == 0: return []
	if DATA[id].stage < 3: return [[seed_id,1]]
	return [[BEETROOT,1],[BEETROOT_SEEDS,2]] if seed_id == BEETROOT_SEEDS else [[seed_id,3]]

static func special(id: int) -> bool:
	return DATA.has(id) and DATA[id].get("block",false) and shape(id) not in ["cube","crop","plant"]

static func recipes(inv: Inventory) -> void:
	inv._recipe("Leads",LEAD,2,[Nodes.STRING,Nodes.STRING,0,Nodes.STRING,Nodes.SLIME_BALL,0,0,0,Nodes.STRING],3,"table")
	var p: int = Nodes.PLANKS; var iron: int = Nodes.IRON
	var defs: Dictionary = {
		BLAST_FURNACE:[iron,iron,iron,iron,Nodes.FURNACE,iron,Nodes.STONE,Nodes.STONE,Nodes.STONE],
		SMOKER:[0,Nodes.LOG,0,Nodes.LOG,Nodes.FURNACE,Nodes.LOG,0,Nodes.LOG,0],
		BARREL:[p,0,p,p,0,p,p,p,p], COMPOSTER:[p,0,p,p,0,p,p,p,p],
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
		CAMPFIRE:[0,Nodes.STICK,0,Nodes.STICK,Nodes.COAL,Nodes.STICK,Nodes.LOG,Nodes.LOG,Nodes.LOG],
		LANTERN:[Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.TORCH,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET],
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
	# Distinct shapes keep barrels and composters craftable without recipe ambiguity.
	for recipe in inv.recipes:
		if recipe.id == COMPOSTER:
			recipe.pattern = [p,0,p,p,0,p,p,Nodes.DIRT,p]; recipe.ingredients = {p:6,Nodes.DIRT:1}
	inv._recipe("Leather from rabbit hides",Nodes.LEATHER,1,[RABBIT_HIDE,RABBIT_HIDE,RABBIT_HIDE,RABBIT_HIDE],2)
	inv._recipe("Leather horse armor",LEATHER_HORSE_ARMOR,1,[Nodes.LEATHER,0,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,Nodes.LEATHER,0,Nodes.LEATHER],3,"table")
	inv._recipe("Emeralds",EMERALD,9,[EMERALD_BLOCK],1)
	inv._recipe("Glass bottles",GLASS_BOTTLE,3,[Nodes.GLASS,0,Nodes.GLASS,0,Nodes.GLASS,0],3,"table")
	inv._recipe("Glass panes",GLASS_PANE,16,[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS],3,"table")
	inv._recipe("Wooden doors",WOODEN_DOOR,3,[p,p,p,p,p,p],2,"table")
	inv._recipe("Cookies",COOKIE,8,[Nodes.GRAIN,COCOA_BEANS,Nodes.GRAIN],3,"table")
	inv._shapeless("Beetroot soup",BEETROOT_SOUP,1,[Nodes.BOWL,BEETROOT,BEETROOT,BEETROOT,BEETROOT,BEETROOT,BEETROOT])
	inv._shapeless("Rabbit stew",RABBIT_STEW,1,[Nodes.BOWL,COOKED_RABBIT,CARROT,BAKED_POTATO,Nodes.BROWN_MUSHROOM])
	inv._recipe("Dried kelp block",DRIED_KELP_BLOCK,1,[DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP,DRIED_KELP],3,"table")
	inv._recipe("Dried kelp",DRIED_KELP,9,[DRIED_KELP_BLOCK],1)
	inv._recipe("Quartz block",QUARTZ_BLOCK,1,[Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ],2)
	for pair in [[GRANITE,POLISHED_GRANITE],[ANDESITE,POLISHED_ANDESITE],[DIORITE,POLISHED_DIORITE]]: inv._recipe(Nodes.title(pair[1]),pair[1],4,[pair[0],pair[0],pair[0],pair[0]],2)
	for pair in [[Nodes.FLOWER,DYE_RED],[Nodes.BONE_MEAL,DYE_WHITE],[INK_SAC,DYE_BLACK],[Nodes.LAPIS,DYE_BLUE],[COCOA_BEANS,DYE_BROWN],[Nodes.CACTUS,DYE_GREEN],[Nodes.PUMPKIN,DYE_YELLOW]]: inv._recipe(Nodes.title(pair[1]),pair[1],1,[pair[0]],1)
	for mix in [[DYE_RED,DYE_YELLOW,DYE_ORANGE],[DYE_RED,DYE_WHITE,DYE_PINK],[DYE_BLUE,DYE_WHITE,DYE_LIGHT_BLUE],[DYE_BLUE,DYE_RED,DYE_PURPLE],[DYE_GREEN,DYE_WHITE,DYE_LIME],[DYE_BLUE,DYE_GREEN,DYE_CYAN],[DYE_BLACK,DYE_WHITE,DYE_GREY],[DYE_GREY,DYE_WHITE,DYE_SILVER],[DYE_PURPLE,DYE_PINK,DYE_MAGENTA]]: inv._shapeless(Nodes.title(mix[2]),mix[2],2,[mix[0],mix[1]])
	for id in DATA:
		var d: Dictionary = DATA[id]; var family: String = d.get("family","")
		if family == "boat":
			if id == BOAT_OAK: inv._recipe(Nodes.title(id),id,1,[p,0,p,p,p,p],3,"table")
			else: inv._shapeless(Nodes.title(id),id,1,[BOAT_OAK,{BOAT_ACACIA:DYE_ORANGE,BOAT_SPRUCE:DYE_BROWN,BOAT_DARK_OAK:DYE_BLACK,BOAT_BIRCH:DYE_WHITE}[id]])
		if family not in ["wool","carpet","bed","banner","terracotta"]: continue
		var color_index: int = id-(WOOL_WHITE if family == "wool" else (CARPET_WHITE if family == "carpet" else (BED_WHITE if family == "bed" else (BANNER_WHITE if family == "banner" else TERRACOTTA_WHITE))))
		var dye: int = DYE_WHITE+color_index; var wool: int = WOOL_WHITE+color_index
		if family == "wool": inv._shapeless(Nodes.title(id),id,1,[Nodes.WOOL,dye])
		if family == "carpet": inv._recipe(Nodes.title(id),id,3,[wool,wool],2)
		if family == "bed": inv._recipe(Nodes.title(id),id,1,[wool,wool,wool,p,p,p],3,"table")
		if family == "banner": inv._recipe(Nodes.title(id),id,1,[wool,wool,wool,wool,wool,wool,0,Nodes.STICK,0],3,"table")
		if family == "terracotta": inv._shapeless(Nodes.title(id),id,1,[Nodes.TERRACOTTA,dye])
