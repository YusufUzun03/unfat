"""Ingredient keys used by the food recipes, mapped to USDA FoodData Central ids.

All ids are SR Legacy (April 2018 release, public domain / CC0). The nutrient
values themselves live in `fdc_ingredients.json`, which `extract_fdc.py`
regenerates from the FDC bulk CSV download.

Approximations (no exact SR Legacy match for a Turkish product) are marked
with "approx" and explained; they are documented in README.md as well.
"""

INGREDIENTS: dict[str, int] = {
    # grains, flours, bakery bases
    "flour": 168936,            # Wheat flour, white, all-purpose, enriched, unbleached
    "rice": 168877,             # Rice, white, long-grain, regular, raw, enriched
    "rice_brown": 169703,       # Rice, brown, long-grain, raw
    "bulgur": 170688,           # Bulgur, dry
    "wheat": 169721,            # Wheat, durum (aşurelik buğday approx)
    "couscous": 169699,         # Couscous, dry (kuskus)
    "quinoa": 168874,           # Quinoa, uncooked (kinoa)
    "pasta": 169736,            # Pasta, dry, enriched (also used for şehriye / erişte)
    "egg_noodles": 169731,      # Noodles, egg, dry, enriched (approx for erişte)
    "oats": 173904,             # Cereals, oats, regular and quick, not fortified, dry
    "semolina": 169715,         # Semolina, enriched (irmik)
    "cornmeal": 168867,         # Cornmeal, degermed, enriched, yellow (mısır unu)
    "cornstarch": 169698,       # Cornstarch (nişasta)
    "bread_white": 174924,      # Bread, white, commercially prepared (approx for Turkish francala/ekmek)
    "bread_ww": 172688,         # Bread, whole-wheat, commercially prepared
    "bread_rye": 172684,        # Bread, rye (çavdar ekmeği)
    "pita": 174915,             # Bread, pita, white, enriched (approx for lavaş / pide bread)
    "phyllo": 172791,           # Phyllo dough (approx for yufka)
    "puff_pastry": 172790,      # Puff pastry, frozen, ready-to-bake (milföy)
    "croissant": 174987,        # Croissants, butter
    "yeast": 175042,            # Leavening agents, yeast, baker's, compressed
    # legumes
    "lentil_red": 174284,       # Lentils, pink or red, raw
    "lentil_green": 172420,     # Lentils, raw
    "white_beans": 175202,      # Beans, white, mature seeds, raw (kuru fasulye)
    "chickpeas": 173756,        # Chickpeas, mature seeds, raw (nohut; also approx for leblebi base)
    "kidney_beans": 175193,     # Beans, kidney, all types, mature seeds, raw
    "cranberry_beans": 175189,  # Beans, cranberry (roman), mature seeds, raw (barbunya)
    "fava_dry": 175205,         # Broadbeans (fava beans), mature seeds, raw
    "fava_fresh": 170377,       # Broadbeans, immature seeds, raw (taze bakla)
    "green_beans": 169961,      # Beans, snap, green, raw (taze fasulye)
    "peas": 170419,             # Peas, green, raw (bezelye)
    # meat, poultry, fish, eggs
    "beef_ground_80": 174036,   # Beef, ground, 80% lean / 20% fat, raw (orta yağlı kıyma)
    "beef_ground_90": 174030,   # Beef, ground, 90% lean / 10% fat, raw (az yağlı kıyma)
    "lamb_ground": 174370,      # Lamb, ground, raw
    "beef_stew": 171206,        # Beef, chuck for stew, lean and fat, all grades, raw (kuşbaşı)
    "beef_round": 171816,       # Beef, round, top round, steak, lean only, raw (bonfile/biftek approx)
    "beef_tbone": 172118,       # Beef, short loin, t-bone steak, lean and fat, raw (antrikot approx)
    "lamb_leg": 174372,         # Lamb, leg, whole, lean and fat, 1/8" fat, raw
    "lamb_shoulder": 172496,    # Lamb, shoulder, whole, lean and fat, 1/4" fat, raw
    "lamb_rib": 174377,         # Lamb, rib, lean and fat, 1/8" fat, raw (pirzola)
    "chicken_breast": 171077,   # Chicken, breast, skinless, boneless, meat only, raw
    "chicken_thigh": 173627,    # Chicken, thigh, meat only, raw
    "chicken_wing": 172390,     # Chicken, wing, meat and skin, raw
    "chicken_drumstick": 172373,  # Chicken, drumstick, meat and skin, raw
    "chicken_whole": 171447,    # Chicken, broilers or fryers, meat and skin, raw
    "turkey_whole": 171081,     # Turkey, whole, meat and skin, raw
    "beef_liver": 169451,       # Beef, liver, raw
    "lamb_liver": 172531,       # Lamb, liver, raw (ciğer)
    "chicken_liver": 171060,    # Chicken, liver, raw
    "tripe": 170599,            # Beef, tripe, raw (işkembe)
    "sucuk": 170606,            # Sausage, beef, cured, cooked, smoked (approx for sucuk)
    "pastirma": 170604,         # Beef, cured, dried (approx for pastırma)
    "salami": 172935,           # Salami, cooked, beef
    "frankfurter": 173862,      # Frankfurter, beef, unheated (sosis)
    "turkey_deli": 174572,      # Turkey breast, deli luncheon meat (hindi füme)
    "anchovy": 174182,          # Fish, anchovy, european, raw (hamsi)
    "sea_bass": 175142,         # Fish, sea bass, mixed species, raw (levrek; also approx for çipura)
    "mackerel": 175119,         # Fish, mackerel, Atlantic, raw (uskumru)
    "salmon": 175167,           # Fish, salmon, Atlantic, farmed, raw (somon)
    "tuna_oil": 173708,         # Fish, tuna, light, canned in oil, drained
    "tuna_water": 171986,       # Fish, tuna, light, canned in water, drained
    "bluefish": 171949,         # Fish, bluefish, raw (lüfer)
    "trout": 173717,            # Fish, trout, rainbow, farmed, raw (alabalık)
    "shrimp": 175179,           # Crustaceans, shrimp, raw (karides)
    "mussel": 174216,           # Mollusks, mussel, blue, raw (midye)
    "squid": 174223,            # Mollusks, squid, raw (kalamar)
    "egg": 171287,              # Egg, whole, raw, fresh
    "egg_white": 172183,        # Egg, white, raw, fresh
    "egg_yolk": 172184,         # Egg, yolk, raw, fresh
    # dairy
    "milk": 171265,             # Milk, whole, 3.25%
    "milk_2": 171267,           # Milk, reduced fat, 2% (approx for yarım yağlı 1.5%)
    "milk_1": 170872,           # Milk, lowfat, 1%
    "milk_powder": 172195,      # Milk, dry, nonfat, regular
    "yogurt": 171284,           # Yogurt, plain, whole milk
    "yogurt_lowfat": 170886,    # Yogurt, plain, low fat
    "greek_yogurt": 171304,     # Yogurt, Greek, plain, whole milk (süzme yoğurt)
    "kefir": 170904,            # Kefir, lowfat, plain
    "feta": 173420,             # Cheese, feta (approx for beyaz peynir / tulum)
    "gouda": 171241,            # Cheese, gouda (approx for kaşar)
    "cheddar": 170899,          # Cheese, cheddar, sharp
    "mozzarella": 170845,       # Cheese, mozzarella, whole milk (approx for dil peyniri)
    "mozzarella_lm": 170846,    # Cheese, mozzarella, whole milk, low moisture (pizza)
    "parmesan": 170848,         # Cheese, parmesan, hard
    "cottage": 172182,          # Cheese, cottage, lowfat, 2%
    "ricotta_ps": 171248,       # Cheese, ricotta, part skim (approx for lor)
    "cream_cheese": 173418,     # Cheese, cream
    "cream_cheese_lf": 169079,  # Cheese, cream, low fat (approx for labne)
    "heavy_cream": 170859,      # Cream, fluid, heavy whipping (krema; also approx for kaymak)
    "sour_cream": 171257,       # Cream, sour, cultured
    "ice_cream": 167575,        # Ice creams, vanilla
    "butter": 173410,           # Butter, salted
    "margarine": 172347,        # Margarine, regular, 80% fat, tub
    # fats and oils
    "olive_oil": 171413,        # Oil, olive, salad or cooking
    "sunflower_oil": 171025,    # Oil, sunflower, linoleic (approx. 65%)
    # vegetables
    "onion": 170000,            # Onions, raw
    "scallion": 170005,         # Onions, spring or scallions, raw
    "garlic": 169230,           # Garlic, raw
    "carrot": 170393,           # Carrots, raw
    "tomato": 170457,           # Tomatoes, red, ripe, raw, year round average
    "tomato_paste": 170459,     # Tomato products, canned, paste (also approx for biber salçası)
    "tomato_sauce": 170054,     # Tomato products, canned, sauce
    "green_pepper": 170427,     # Peppers, sweet, green, raw (dolmalık/çarliston approx)
    "red_pepper": 170108,       # Peppers, sweet, red, raw (kapya)
    "hot_pepper": 170497,       # Peppers, hot chili, green, raw (sivri)
    "cucumber": 168409,         # Cucumber, with peel, raw
    "eggplant": 169228,         # Eggplant, raw
    "zucchini": 169291,         # Squash, summer, zucchini, includes skin, raw
    "potato": 170026,           # Potatoes, flesh and skin, raw
    "spinach": 168462,          # Spinach, raw
    "parsley": 170416,          # Parsley, fresh
    "dill": 172233,             # Dill weed, fresh
    "mint_fresh": 173475,       # Spearmint, fresh
    "mint_dried": 172239,       # Spearmint, dried
    "leek": 169246,             # Leeks, raw
    "celeriac": 170400,         # Celeriac, raw
    "cabbage": 169975,          # Cabbage, raw
    "red_cabbage": 169977,      # Cabbage, red, raw
    "lettuce_iceberg": 169248,  # Lettuce, iceberg, raw
    "lettuce_romaine": 169247,  # Lettuce, cos or romaine, raw
    "cauliflower": 169986,      # Cauliflower, raw
    "broccoli": 170379,         # Broccoli, raw
    "pumpkin": 168448,          # Pumpkin, raw (balkabağı)
    "okra": 169260,             # Okra, raw (bamya)
    "artichoke": 169205,        # Artichokes, globe, raw (enginar)
    "corn": 169998,             # Corn, sweet, yellow, raw (mısır koçanı)
    "corn_canned": 169214,      # Corn, sweet, yellow, canned, drained
    "mushroom": 169251,         # Mushrooms, white, raw
    "beet": 169145,             # Beets, raw (pancar)
    "radish": 169276,           # Radishes, raw (turp)
    "arugula": 169387,          # Arugula, raw (roka)
    "purslane": 169274,         # Purslane, raw (semizotu)
    "grape_leaves": 168575,     # Grape leaves, raw (asma yaprağı)
    "olive_black": 169094,      # Olives, ripe, canned (approx for siyah zeytin)
    "olive_green": 169096,      # Olives, pickled, green
    "pickle": 168558,           # Pickles, cucumber, dill (turşu approx)
    "lemon_juice": 167747,      # Lemon juice, raw
    "chestnut": 170190,         # Nuts, chestnuts, european, roasted
    # fruits
    "lemon": 167746,            # Lemons, raw, without peel
    "apple": 171688,            # Apples, raw, with skin
    "banana": 173944,           # Bananas, raw
    "orange": 169097,           # Oranges, raw, all commercial varieties
    "mandarin": 169105,         # Tangerines (mandarin oranges), raw
    "grapes": 174683,           # Grapes, red or green, raw
    "watermelon": 167765,       # Watermelon, raw
    "melon": 169911,            # Melons, honeydew, raw (approx for kavun)
    "strawberry": 167762,       # Strawberries, raw
    "cherry": 171719,           # Cherries, sweet, raw
    "sour_cherry": 173954,      # Cherries, sour, red, raw (vişne)
    "apricot": 171697,          # Apricots, raw
    "apricot_dried": 173941,    # Apricots, dried, sulfured, uncooked
    "peach": 169928,            # Peaches, yellow, raw
    "pear": 169118,             # Pears, raw
    "plum": 169949,             # Plums, raw (erik)
    "fig": 173021,              # Figs, raw
    "fig_dried": 174665,        # Figs, dried, uncooked
    "pomegranate": 169134,      # Pomegranates, raw
    "kiwi": 168153,             # Kiwifruit, green, raw
    "quince": 168163,           # Quinces, raw (ayva)
    "dates": 168191,            # Dates, medjool (hurma)
    "raisins": 168165,          # Raisins, dark, seedless (kuru üzüm)
    "mulberry": 169913,         # Mulberries, raw (dut)
    "grapefruit": 174673,       # Grapefruit, raw, pink and red
    "pineapple": 169124,        # Pineapple, raw
    "persimmon": 169941,        # Persimmons, japanese, raw (trabzon hurması)
    # nuts and seeds
    "hazelnut": 170581,         # Nuts, hazelnuts or filberts (fındık)
    "walnut": 170187,           # Nuts, walnuts, english (ceviz)
    "almond": 170567,           # Nuts, almonds (badem)
    "pistachio": 169426,        # Nuts, pistachio, dry roasted, salted (Antep fıstığı)
    "peanut": 174262,           # Peanuts, dry-roasted, salted (yer fıstığı)
    "cashew": 169421,           # Nuts, cashew, dry roasted, salted
    "sunflower_seeds": 169418,  # Seeds, sunflower kernels, dry roasted, salted (çekirdek içi)
    "pumpkin_seeds": 169415,    # Seeds, pumpkin kernels, roasted, salted (kabak çekirdeği içi)
    "sesame": 170150,           # Seeds, sesame seeds, whole, dried (susam)
    "tahini": 170189,           # Seeds, sesame butter, tahini, roasted kernels
    "coconut": 168586,          # Coconut, dried, shredded, sweetened (hindistan cevizi)
    # sweeteners, sweets
    "sugar": 169655,            # Sugars, granulated
    "powdered_sugar": 169656,   # Sugars, powdered (pudra şekeri)
    "brown_sugar": 168833,      # Sugars, brown
    "honey": 169640,            # Honey (bal)
    "molasses": 168820,         # Molasses (approx for üzüm/dut pekmezi)
    "jam": 169641,              # Jams and preserves (reçel)
    "dark_chocolate": 170273,   # Chocolate, dark, 70-85% cacao
    "milk_chocolate": 167587,   # Candies, milk chocolate
    "hazelnut_spread": 168000,  # Chocolate-flavored hazelnut spread (kakaolu fındık kreması)
    "cocoa": 169593,            # Cocoa, dry powder, unsweetened
    "gelatin": 169599,          # Gelatins, dry powder, unsweetened
    # condiments
    "vinegar": 173469,          # Vinegar, cider (sirke)
    "mayonnaise": 171009,       # Salad dressing, mayonnaise, regular
    "ketchup": 168556,          # Catsup (ketçap)
    "mustard": 172234,          # Mustard, prepared, yellow (hardal)
    "salt": 173468,             # Salt, table
    "pepper_flakes": 170932,    # Spices, pepper, red or cayenne (pul biber approx)
    "cinnamon": 171320,         # Spices, cinnamon, ground (tarçın)
    # packaged snacks and fast-food components
    "potato_chips": 169677,     # Snacks, potato chips, plain, salted (cips)
    "popcorn": 167959,          # Snacks, popcorn, air-popped (patlamış mısır)
    "crackers": 172746,         # Crackers, saltines (kraker)
    "butter_cookies": 174950,   # Cookies, butter, commercially prepared (bisküvi)
    "sandwich_cookies": 172718, # Cookies, chocolate sandwich, with creme filling
    "fries": 170698,            # Fast foods, potato, french fried in vegetable oil
    "nuggets": 172112,          # Chicken nuggets, white meat, precooked, frozen
    # drinks
    "water": 173647,            # Beverages, water, tap, drinking
    "club_soda": 174842,        # Beverages, carbonated, club soda (soda / maden suyu)
    "tea": 173227,              # Beverages, tea, black, brewed
    "coffee": 171890,           # Beverages, coffee, brewed
    "espresso": 171891,         # Beverages, coffee, brewed, espresso (approx for Türk kahvesi)
    "cola": 174852,             # Beverages, carbonated, cola, regular
    "orange_juice": 169098,     # Orange juice, raw
    "apple_juice": 173933,      # Apple juice, canned or bottled, unsweetened
    "energy_drink": 173210,     # Beverages, Energy drink (sugar-sweetened)
    "soymilk": 172446,          # Soymilk, original and vanilla, unfortified
    "almond_milk": 174832,      # Beverages, almond milk, unsweetened
    "beer": 168746,             # Alcoholic beverage, beer, regular, all
    "wine_red": 173190,         # Alcoholic beverage, wine, table, red
    "spirits_90": 171920,       # Alcoholic beverage, distilled, 90 proof (approx for rakı, 45 %)
}
