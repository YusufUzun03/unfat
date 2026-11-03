"""UnFat Turkish food table: own recipe compositions over USDA FDC ingredients.

Every recipe below is UnFat's own composition of common Turkish home / street
cooking (no TürKomp or other unlicensed table data). Nutrient values come only
from the USDA FDC ingredients listed in fdc_ingredients.py.

DSL
  B(key, ingredients, yield)            reusable cooked base, referenced as "@key"
  R(name, category, ingredients, yield, servings, aliases="", note="")

ingredients: "key grams, key grams, ..."  (key from fdc_ingredients.py or @base)
yield:       cooked mass / total raw mass (incl. water). Water that is drained
             away (pasta/legume boiling) is NOT listed; only absorbed water is.
             Fried items list only the oil that stays in the food.
servings:    "label grams, label grams"  (label = Turkish lowercase unit)

Ids are assigned by generate.py through id_lock.json (name -> id), so editing,
reordering or appending recipes never changes an existing id. Never rename a
food casually: a rename gets a new id.
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Base:
    key: str
    ingredients: str
    yield_: float


@dataclass
class Recipe:
    name: str
    category: str
    ingredients: str
    yield_: float
    servings: str
    aliases: list[str] = field(default_factory=list)
    note: str = ""


BASES: list[Base] = []
RECIPES: list[Recipe] = []


def B(key: str, ingredients: str, yield_: float) -> None:
    BASES.append(Base(key, ingredients, yield_))


def R(name: str, category: str, ingredients: str, yield_: float, servings: str,
      aliases: str = "", note: str = "") -> None:
    al = [a.strip() for a in aliases.split(",") if a.strip()]
    RECIPES.append(Recipe(name, category, ingredients, yield_, servings, al, note))


# ---------------------------------------------------------------- bases
B("pilav", "rice 500, butter 40, sunflower_oil 20, water 750, salt 10", 0.98)
B("bulgur_pilav", "bulgur 400, onion 80, green_pepper 50, tomato_paste 25, butter 30, "
  "sunflower_oil 20, water 900, salt 8", 0.95)
B("lavas", "flour 1000, water 600, yeast 10, salt 15, sunflower_oil 20", 0.85)
B("pide_dough", "flour 1000, water 580, yeast 15, salt 15, sunflower_oil 30", 0.85)
B("gozleme_dough", "flour 1000, water 550, salt 15", 0.9)
B("doner_beef", "beef_stew 600, lamb_shoulder 300, sunflower_oil 30, onion 100, yogurt 50, salt 15", 0.62)
B("doner_chicken", "chicken_thigh 1000, yogurt 100, sunflower_oil 50, tomato_paste 20, salt 15", 0.7)
B("kofte", "beef_ground_80 1000, onion 150, bread_white 80, salt 15", 0.72)
B("burger_patty", "beef_ground_80 1000, salt 10", 0.72)
B("chicken_grilled", "chicken_breast 1000, olive_oil 20, salt 8", 0.72)
B("manti_plain", "flour 300, egg 50, water 300, beef_ground_80 150, onion 50, salt 5", 1.0)
B("bechamel", "butter 50, flour 50, milk 500", 0.9)
B("cig_kofte", "bulgur 500, tomato_paste 150, onion 150, olive_oil 50, walnut 50, water 300, "
  "parsley 50, pepper_flakes 20, molasses 20, salt 15", 0.95)
B("kaymak", "heavy_cream 60, butter 40", 1.0)

# ---------------------------------------------------------------- soups
SOUP = "kase 250, kepçe 120"
R("Mercimek çorbası", "soup", "lentil_red 200, onion 100, carrot 80, butter 30, sunflower_oil 15, "
  "flour 15, tomato_paste 15, water 1800, salt 10", 0.85, SOUP, "mercimek, kırmızı mercimek çorbası")
R("Ezogelin çorbası", "soup", "lentil_red 150, bulgur 40, rice 30, onion 100, tomato_paste 30, "
  "butter 30, sunflower_oil 15, mint_dried 5, pepper_flakes 3, water 1800, salt 10", 0.85, SOUP, "ezogelin")
R("Yeşil mercimek çorbası", "soup", "lentil_green 200, onion 100, carrot 80, tomato_paste 20, "
  "butter 20, sunflower_oil 15, water 1800, salt 10", 0.85, SOUP)
R("Yayla çorbası", "soup", "yogurt 400, rice 60, egg_yolk 20, flour 20, butter 30, mint_dried 5, "
  "water 1300, salt 8", 0.9, SOUP, "yoğurt çorbası")
R("Domates çorbası", "soup", "tomato 600, tomato_paste 30, flour 40, butter 30, milk 200, "
  "water 1000, salt 8", 0.85, SOUP)
R("Tavuk suyu çorbası", "soup", "chicken_breast 200, pasta 60, carrot 50, butter 15, lemon_juice 20, "
  "water 1800, salt 8", 0.85, SOUP, "tavuk çorbası, şehriyeli tavuk çorbası")
R("Kremalı tavuk çorbası", "soup", "chicken_breast 250, flour 50, butter 40, milk 400, heavy_cream 50, "
  "water 1200, salt 8", 0.85, SOUP)
R("Şehriye çorbası", "soup", "pasta 80, tomato_paste 20, butter 25, sunflower_oil 10, water 1500, "
  "salt 8", 0.85, SOUP, "şehriyeli çorba")
R("Tarhana çorbası", "soup", "flour 60, yogurt 40, tomato_paste 20, red_pepper 20, butter 25, "
  "water 1300, salt 8", 0.85, SOUP, "tarhana")
R("Düğün çorbası", "soup", "lamb_shoulder 200, flour 40, butter 40, egg_yolk 40, yogurt 100, "
  "lemon_juice 20, water 1700, salt 8", 0.85, SOUP)
R("İşkembe çorbası", "soup", "tripe 400, flour 40, butter 40, egg_yolk 20, lemon_juice 20, garlic 10, "
  "vinegar 20, water 1500, salt 8", 0.85, SOUP, "işkembe")
R("Mantar çorbası", "soup", "mushroom 400, onion 80, butter 40, flour 40, milk 400, heavy_cream 100, "
  "water 900, salt 8", 0.85, SOUP, "kremalı mantar çorbası")
R("Brokoli çorbası", "soup", "broccoli 400, onion 80, potato 100, butter 30, milk 300, water 900, "
  "salt 8", 0.85, SOUP)
R("Sebze çorbası", "soup", "carrot 150, potato 200, zucchini 150, onion 100, peas 80, tomato_paste 20, "
  "olive_oil 30, water 1500, salt 8", 0.85, SOUP)
R("Balkabağı çorbası", "soup", "pumpkin 700, onion 80, carrot 80, butter 30, heavy_cream 100, "
  "water 800, salt 8", 0.85, SOUP, "kabak çorbası")
R("Karalahana çorbası", "soup", "cabbage 400, cranberry_beans 80, cornmeal 40, onion 80, butter 30, "
  "water 1500, salt 8", 0.85, SOUP, "lahana çorbası", "white cabbage used for kale (no SR kale match chosen)")
R("Patates çorbası", "soup", "potato 500, onion 80, butter 30, milk 300, water 900, salt 8", 0.85, SOUP)
R("Mısır çorbası", "soup", "corn_canned 300, butter 30, flour 40, milk 500, water 700, salt 8", 0.85, SOUP)
R("Balık çorbası", "soup", "sea_bass 300, potato 150, carrot 80, onion 80, olive_oil 30, lemon_juice 20, "
  "flour 20, water 1500, salt 8", 0.85, SOUP)
R("Toyga çorbası", "soup", "yogurt 400, wheat 60, chickpeas 40, butter 30, mint_dried 5, flour 20, "
  "water 1400, salt 8", 0.85, SOUP, "toyga")

# ---------------------------------------------------------------- mains
P = "porsiyon 250"
R("Kuru fasulye", "main", "white_beans 500, beef_stew 200, onion 150, tomato_paste 40, "
  "sunflower_oil 40, butter 20, water 2000, salt 12", 0.75, "porsiyon 250, kepçe 150",
  "etli kuru fasulye, kuru")
R("Etsiz kuru fasulye", "main", "white_beans 500, onion 150, tomato_paste 40, sunflower_oil 60, "
  "water 2000, salt 12", 0.75, "porsiyon 250, kepçe 150", "zeytinyağlı kuru fasulye")
R("Etli nohut", "main", "chickpeas 500, beef_stew 200, onion 150, tomato_paste 40, sunflower_oil 40, "
  "butter 20, water 2000, salt 12", 0.75, "porsiyon 250, kepçe 150", "nohut yemeği, nohut")
R("Karnıyarık", "main", "eggplant 1000, beef_ground_80 300, onion 150, green_pepper 100, tomato 200, "
  "tomato_paste 20, sunflower_oil 150, water 200, salt 10", 0.7, "adet 150, porsiyon 300")
R("İmam bayıldı", "main", "eggplant 1000, onion 300, tomato 300, garlic 20, olive_oil 150, sugar 10, "
  "water 150, salt 10", 0.7, "adet 150, porsiyon 300")
R("Musakka", "main", "eggplant 800, beef_ground_80 300, onion 150, tomato 200, tomato_paste 20, "
  "sunflower_oil 120, water 200, salt 10", 0.72, P, "patlıcan musakka")
R("Patlıcan kebabı", "main", "eggplant 600, beef_ground_80 400, tomato 200, green_pepper 100, "
  "onion 50, salt 8", 0.7, "porsiyon 300")
R("Hünkar beğendi", "main", "eggplant 800, butter 50, flour 40, milk 400, gouda 60, beef_stew 500, "
  "onion 150, tomato 200, tomato_paste 20, sunflower_oil 30, water 300, salt 10", 0.7, "porsiyon 300")
R("Ali Nazik", "main", "eggplant 600, yogurt 300, beef_ground_80 300, butter 30, garlic 10, salt 8",
  0.7, "porsiyon 300", "alinazik")
R("Kuzu tandır", "main", "lamb_leg 1000, salt 10", 0.65, "porsiyon 200", "tandır")
R("Tas kebabı", "main", "beef_stew 600, onion 200, tomato 200, tomato_paste 30, butter 30, "
  "sunflower_oil 20, flour 10, water 500, salt 10", 0.7, P)
R("Orman kebabı", "main", "beef_stew 500, potato 300, carrot 150, peas 150, onion 150, tomato_paste 20, "
  "sunflower_oil 40, water 500, salt 10", 0.75, P)
R("Et sote", "main", "beef_stew 600, onion 150, green_pepper 150, tomato 200, sunflower_oil 40, "
  "butter 20, salt 10", 0.7, "porsiyon 200", "dana sote")
R("Tavuk sote", "main", "chicken_breast 600, onion 150, green_pepper 150, tomato 200, mushroom 100, "
  "sunflower_oil 40, salt 10", 0.75, "porsiyon 200")
R("Tavuk şiş", "main", "chicken_breast 1000, yogurt 100, olive_oil 40, tomato_paste 20, garlic 10, "
  "salt 12", 0.72, "porsiyon 200, adet 100", "şiş tavuk")
R("Adana kebap", "main", "lamb_ground 700, beef_ground_80 300, red_pepper 100, pepper_flakes 10, "
  "salt 15", 0.7, "porsiyon 200, adet 100", "adana", "meat only, without lavaş and garnish")
R("Urfa kebap", "main", "lamb_ground 700, beef_ground_80 300, red_pepper 100, salt 15", 0.7,
  "porsiyon 200, adet 100", "urfa", "meat only, without lavaş and garnish")
R("İskender", "main", "@doner_beef 150, pita 80, tomato_sauce 60, butter 20, yogurt 100", 1.0,
  "porsiyon 410", "iskender kebap")
R("Beyti", "main", "@kofte 200, @lavas 60, tomato_sauce 50, yogurt 100, butter 15", 1.0,
  "porsiyon 425", "beyti sarma")
R("Izgara köfte", "main", "@kofte 100", 1.0, "porsiyon 200, adet 30", "köfte, ızgara köfte")
R("Kadınbudu köfte", "main", "beef_ground_80 500, rice 80, water 150, onion 100, egg 150, flour 50, "
  "sunflower_oil 120, salt 8", 0.8, "adet 80, porsiyon 240")
R("Sulu köfte", "main", "beef_ground_80 400, rice 60, onion 80, potato 200, carrot 100, tomato_paste 20, "
  "flour 30, butter 20, water 1500, salt 10", 0.85, "kase 250, porsiyon 300", "ekşili köfte, terbiyeli köfte")
R("İzmir köfte", "main", "@kofte 300, potato 400, green_pepper 100, tomato 200, tomato_paste 20, "
  "sunflower_oil 60, water 300, salt 8", 0.8, "porsiyon 300")
R("İçli köfte", "main", "bulgur 300, semolina 50, beef_ground_80 300, onion 150, walnut 50, "
  "sunflower_oil 150, water 200, salt 10", 0.85, "adet 60, porsiyon 180")
R("Kıymalı patates", "main", "potato 600, beef_ground_80 250, onion 100, tomato_paste 20, "
  "sunflower_oil 30, water 300, salt 8", 0.85, P, "patates yemeği")
R("Etli bezelye", "main", "peas 600, beef_stew 200, onion 100, carrot 150, potato 150, tomato_paste 20, "
  "sunflower_oil 30, water 500, salt 8", 0.8, P, "bezelye yemeği")
R("Türlü", "main", "eggplant 300, zucchini 300, green_beans 200, potato 200, green_pepper 100, tomato 300, "
  "onion 150, beef_stew 250, sunflower_oil 60, water 300, salt 10", 0.8, P)
R("Etli kabak yemeği", "main", "zucchini 1000, beef_ground_80 200, onion 100, tomato 200, rice 40, "
  "sunflower_oil 30, water 200, salt 8", 0.8, P, "kabak yemeği")
R("Etli ıspanak", "main", "spinach 1000, beef_ground_80 200, onion 100, rice 40, tomato_paste 20, "
  "sunflower_oil 30, water 200, salt 8", 0.7, P, "ıspanak yemeği")
R("Etli taze fasulye", "main", "green_beans 1000, beef_stew 250, onion 150, tomato 300, "
  "sunflower_oil 40, water 300, salt 10", 0.8, P)
R("Etli biber dolması", "main", "green_pepper 600, rice 200, beef_ground_80 300, onion 150, tomato 150, "
  "tomato_paste 30, sunflower_oil 40, mint_dried 5, water 600, salt 10", 0.85, "adet 100, porsiyon 300",
  "biber dolması, dolma")
R("Etli yaprak sarma", "main", "grape_leaves 250, rice 300, beef_ground_80 300, onion 150, "
  "tomato_paste 30, sunflower_oil 40, water 800, salt 10", 0.8, "adet 30, porsiyon 240", "etli sarma")
R("Lahana sarması", "main", "cabbage 800, rice 250, beef_ground_80 250, onion 100, tomato_paste 30, "
  "sunflower_oil 40, water 600, salt 10", 0.85, "adet 60, porsiyon 300", "lahana dolması")
R("Mantı", "main", "@manti_plain 250, yogurt 100, butter 15, tomato_paste 5", 1.0, "porsiyon 370",
  "yoğurtlu mantı, kayseri mantısı")
R("Çökertme kebabı", "main", "beef_round 300, potato 300, sunflower_oil 60, yogurt 200, butter 20, "
  "garlic 5, salt 6", 0.8, "porsiyon 300", "çökertme")
R("Etli güveç", "main", "beef_stew 500, eggplant 200, tomato 300, green_pepper 100, onion 150, "
  "potato 200, sunflower_oil 40, water 200, salt 10", 0.8, "porsiyon 300", "güveç")
R("Fırın tavuk", "main", "chicken_whole 1000, potato 600, onion 100, tomato_paste 20, sunflower_oil 50, "
  "salt 12", 0.75, "porsiyon 300", "patatesli fırın tavuk")
R("Pilav üstü tavuk döner", "main", "@doner_chicken 150, @pilav 200", 1.0, "porsiyon 350")
R("Pilav üstü et döner", "main", "@doner_beef 120, @pilav 200", 1.0, "porsiyon 320")
R("Tavuklu nohutlu pilav", "main", "rice 500, chickpeas 100, chicken_breast 300, butter 50, water 1100, "
  "salt 12", 0.9, "porsiyon 300", "nohutlu tavuklu pilav, sokak pilavı")
R("Arnavut ciğeri", "main", "lamb_liver 500, flour 40, sunflower_oil 60, onion 150, salt 6", 0.75,
  "porsiyon 200", "ciğer tava")
R("Tavuk ciğeri sote", "main", "chicken_liver 500, onion 100, butter 30, salt 5", 0.75, "porsiyon 200")
R("Hamsi tava", "main", "anchovy 1000, cornmeal 100, sunflower_oil 100, salt 10", 0.8,
  "porsiyon 250, adet 12", "hamsi kızartma")
R("Hamsili pilav", "main", "anchovy 400, rice 400, butter 40, onion 80, water 600, salt 8", 0.9,
  "dilim 200, porsiyon 250")
R("Karides güveç", "main", "shrimp 500, tomato 300, green_pepper 100, gouda 100, butter 40, garlic 10, "
  "salt 6", 0.8, "porsiyon 200")
R("Kalamar tava", "main", "squid 500, flour 80, egg 50, water 60, sunflower_oil 80, salt 5", 0.85,
  "porsiyon 200", "kalamar")
R("Midye tava", "main", "mussel 500, flour 100, egg 50, water 100, sunflower_oil 100, salt 5", 0.85,
  "porsiyon 200, adet 15")
R("Fırın makarna", "main", "pasta 500, water 650, milk 500, egg 100, butter 50, gouda 150, flour 30, "
  "salt 8", 0.95, "dilim 200, porsiyon 250", "makarna fırın")
R("Salçalı makarna", "main", "pasta 500, water 650, sunflower_oil 30, tomato_paste 40, salt 8", 0.97,
  "porsiyon 250, tabak 300", "makarna")
R("Spagetti bolonez", "main", "pasta 400, water 520, beef_ground_80 300, onion 100, tomato_sauce 300, "
  "olive_oil 30, salt 8", 0.9, "porsiyon 300, tabak 350", "bolonez")
R("Tereyağlı erişte", "main", "egg_noodles 400, water 500, butter 40, walnut 30, salt 6", 0.97,
  "porsiyon 250", "erişte")
R("Kıymalı pide", "main", "@pide_dough 180, beef_ground_80 100, onion 30, tomato 30, green_pepper 20, "
  "butter 15", 0.92, "adet 345, dilim 60")
R("Kaşarlı pide", "main", "@pide_dough 180, gouda 100, butter 15", 0.95, "adet 280, dilim 50", "peynirli pide")
R("Kuşbaşılı pide", "main", "@pide_dough 180, beef_stew 120, tomato 30, green_pepper 20, butter 15",
  0.9, "adet 330, dilim 55")
R("Karışık pide", "main", "@pide_dough 180, beef_ground_80 60, sucuk 30, gouda 60, egg 50, butter 10",
  0.92, "adet 360, dilim 60")
R("Yumurtalı kaşarlı pide", "main", "@pide_dough 180, gouda 80, egg 100, butter 10", 0.93, "adet 345, dilim 55")
R("Lahmacun", "main", "flour 1000, water 600, yeast 10, salt 15, beef_ground_80 500, onion 300, "
  "tomato 300, green_pepper 200, tomato_paste 80, parsley 50, sunflower_oil 30", 0.7, "adet 130")
R("Ispanaklı börek (kol)", "main", "phyllo 500, spinach 500, onion 100, feta 200, milk 200, egg 100, "
  "sunflower_oil 100, butter 50, salt 5", 0.8, "dilim 150", "ıspanaklı kol böreği")
R("Kuzu şiş", "main", "lamb_leg 1000, olive_oil 20, onion 50, salt 10", 0.7, "porsiyon 200, adet 100", "şiş kebap")
R("Ciğer şiş", "main", "lamb_liver 1000, sunflower_oil 20, salt 10", 0.75, "porsiyon 200, adet 80")
R("Kanat (ızgara)", "main", "chicken_wing 1000, yogurt 50, tomato_paste 20, olive_oil 20, salt 10",
  0.7, "porsiyon 250, adet 35", "tavuk kanat")
R("Kavurma", "main", "beef_stew 1000, butter 60, salt 12", 0.65, "porsiyon 150", "et kavurma")
R("Tantuni", "fastfood", "@lavas 60, beef_round 100, sunflower_oil 15, tomato 30, onion 20, parsley 5, "
  "salt 2", 0.85, "adet 195", "tantuni dürüm")
R("Çiğ köfte", "snack", "@cig_kofte 100", 1.0, "porsiyon 150, adet 30", "etsiz çiğ köfte")

# ---------------------------------------------------------------- sides
R("Pirinç pilavı", "side", "@pilav 100", 1.0, "porsiyon 180, yemek kaşığı 25, kase 200", "pilav, tereyağlı pilav")
R("Bulgur pilavı", "side", "@bulgur_pilav 100", 1.0, "porsiyon 180, yemek kaşığı 25, kase 200", "bulgur")
R("Şehriyeli pilav", "side", "rice 450, pasta 60, butter 40, sunflower_oil 20, water 780, salt 10", 0.97,
  "porsiyon 180, yemek kaşığı 25")
R("Nohutlu pilav", "side", "rice 500, chickpeas 100, butter 40, sunflower_oil 20, water 1000, salt 10",
  0.95, "porsiyon 180, yemek kaşığı 25")
R("İç pilav", "side", "rice 500, onion 100, raisins 30, butter 50, chicken_liver 100, almond 30, "
  "water 750, salt 10", 0.95, "porsiyon 180")
R("Patates püresi", "side", "potato 1000, milk 200, butter 60, salt 8", 0.9, "porsiyon 200, yemek kaşığı 30", "püre")
R("Fırın patates", "side", "potato 1000, olive_oil 50, salt 8", 0.8, "porsiyon 200", "fırında patates")
R("Patates kızartması", "side", "fries 100", 1.0, "porsiyon 150, avuç 40", "kızarmış patates, cips patates")
R("Mücver", "side", "zucchini 600, egg 150, flour 100, feta 100, dill 20, scallion 50, sunflower_oil 100, "
  "salt 6", 0.75, "adet 50, porsiyon 200", "kabak mücver")
R("Zeytinyağlı taze fasulye", "side", "green_beans 1000, onion 150, tomato 300, olive_oil 80, sugar 10, "
  "water 300, salt 10", 0.8, P, "taze fasulye")
R("Zeytinyağlı biber dolması", "side", "green_pepper 600, rice 300, onion 300, olive_oil 120, sugar 10, "
  "raisins 20, water 700, salt 10", 0.85, "adet 80, porsiyon 240")
R("Zeytinyağlı yaprak sarma", "side", "grape_leaves 250, rice 400, onion 400, olive_oil 150, "
  "lemon_juice 50, sugar 10, raisins 30, water 900, salt 10", 0.8, "adet 25, porsiyon 200",
  "yaprak sarma, sarma")
R("Zeytinyağlı enginar", "side", "artichoke 600, carrot 150, peas 100, potato 150, onion 100, "
  "olive_oil 80, lemon_juice 40, sugar 10, water 300, salt 8", 0.85, "adet 120, porsiyon 200", "enginar")
R("Zeytinyağlı barbunya", "side", "cranberry_beans 400, onion 150, carrot 100, tomato 200, olive_oil 100, "
  "water 1200, salt 10", 0.75, "porsiyon 200", "barbunya pilaki, barbunya")
R("Zeytinyağlı pırasa", "side", "leek 800, carrot 150, rice 40, olive_oil 80, lemon_juice 20, sugar 10, "
  "water 300, salt 8", 0.85, "porsiyon 200", "pırasa")
R("Zeytinyağlı kereviz", "side", "celeriac 700, carrot 150, potato 100, peas 80, onion 80, olive_oil 80, "
  "orange_juice 100, lemon_juice 30, sugar 10, water 200, salt 8", 0.85, "porsiyon 200", "kereviz")
R("Zeytinyağlı bamya", "side", "okra 600, onion 100, tomato 300, olive_oil 60, lemon_juice 30, "
  "water 200, salt 8", 0.85, "porsiyon 200", "bamya")
R("Zeytinyağlı kabak", "side", "zucchini 1000, onion 100, carrot 100, rice 40, olive_oil 60, dill 20, "
  "water 150, salt 8", 0.85, "porsiyon 200")
R("Şakşuka", "side", "eggplant 600, zucchini 200, potato 200, green_pepper 100, sunflower_oil 150, "
  "tomato 300, garlic 10, salt 8", 0.75, "porsiyon 150")
R("Patlıcan kızartması", "side", "eggplant 800, sunflower_oil 160, salt 6", 0.65, "porsiyon 150, dilim 30")
R("Biber kızartması", "side", "hot_pepper 500, sunflower_oil 60, salt 4", 0.8, "adet 15, porsiyon 100")
R("Karnabahar kızartması", "side", "cauliflower 600, flour 60, egg 100, sunflower_oil 120, salt 6", 0.8,
  "porsiyon 150")
R("Humus", "side", "chickpeas 250, water 300, tahini 100, lemon_juice 50, olive_oil 40, garlic 10, "
  "salt 6", 0.9, "yemek kaşığı 20, porsiyon 100", "hummus")
R("Haydari", "side", "greek_yogurt 400, feta 50, garlic 10, dill 10, mint_dried 3, olive_oil 20, salt 3",
  1.0, "yemek kaşığı 20, porsiyon 100")
R("Cacık", "side", "yogurt 400, cucumber 200, water 200, garlic 5, mint_dried 3, olive_oil 10, salt 4",
  1.0, "kase 200, yemek kaşığı 20")
R("Acılı ezme", "side", "tomato 400, red_pepper 100, hot_pepper 50, onion 100, parsley 30, "
  "tomato_paste 30, pepper_flakes 5, olive_oil 40, lemon_juice 20, molasses 20, salt 6", 0.9,
  "yemek kaşığı 20, porsiyon 100", "ezme, acılı ezme salatası")
R("Babagannuş", "side", "eggplant 800, olive_oil 40, tomato 100, green_pepper 50, garlic 5, salt 4", 0.7,
  "yemek kaşığı 20, porsiyon 100")
R("Muhammara", "side", "red_pepper 400, walnut 150, bread_white 60, olive_oil 60, tomato_paste 30, "
  "molasses 20, pepper_flakes 5, garlic 5, salt 4", 0.8, "yemek kaşığı 20, porsiyon 100", "acuka")
R("Fava", "side", "fava_dry 300, onion 100, olive_oil 80, water 900, dill 10, sugar 5, salt 6", 0.7,
  "dilim 80, porsiyon 100")
R("Patlıcan salatası", "salad", "eggplant 1000, olive_oil 50, garlic 10, lemon_juice 30, green_pepper 50, "
  "salt 6", 0.65, "porsiyon 150, yemek kaşığı 20", "közlenmiş patlıcan")

# ---------------------------------------------------------------- salads
SAL = "porsiyon 200, kase 200, tabak 300"
R("Çoban salatası", "salad", "tomato 300, cucumber 300, green_pepper 100, onion 100, parsley 30, "
  "olive_oil 40, lemon_juice 30, salt 5", 1.0, SAL, "çoban")
R("Mevsim salatası", "salad", "lettuce_romaine 200, arugula 50, tomato 150, cucumber 150, carrot 80, "
  "red_cabbage 50, olive_oil 40, lemon_juice 30, salt 5", 1.0, SAL, "yeşil salata")
R("Gavurdağı salatası", "salad", "tomato 400, onion 100, green_pepper 100, walnut 60, parsley 30, "
  "olive_oil 50, molasses 30, salt 5", 1.0, SAL, "gavurdağı")
R("Roka salatası", "salad", "arugula 200, tomato 100, onion 50, parmesan 20, olive_oil 30, "
  "lemon_juice 20, salt 3", 1.0, SAL)
R("Semizotu salatası", "salad", "purslane 300, yogurt 300, garlic 5, olive_oil 15, salt 4", 1.0, SAL,
  "yoğurtlu semizotu")
R("Patates salatası", "salad", "potato 800, scallion 80, parsley 40, dill 20, olive_oil 60, "
  "lemon_juice 40, salt 8", 0.95, SAL)
R("Piyaz", "salad", "white_beans 300, water 450, onion 150, parsley 40, tomato 150, olive_oil 60, "
  "lemon_juice 30, vinegar 20, egg 50, salt 6", 0.95, SAL, "fasulye piyazı")
R("Kısır", "salad", "bulgur 300, water 350, tomato_paste 40, olive_oil 80, scallion 80, parsley 80, "
  "lemon_juice 40, molasses 20, tomato 150, salt 6", 0.95, "porsiyon 150, kase 200, yemek kaşığı 25")
R("Ton balıklı salata", "salad", "tuna_oil 160, lettuce_iceberg 200, corn_canned 80, tomato 100, "
  "cucumber 100, olive_oil 20, lemon_juice 20, salt 3", 1.0, SAL, "ton balıklı")
R("Tavuklu salata", "salad", "@chicken_grilled 150, lettuce_romaine 150, tomato 100, cucumber 100, "
  "corn_canned 50, olive_oil 20, lemon_juice 15, salt 3", 1.0, SAL)
R("Sezar salata", "salad", "lettuce_romaine 200, @chicken_grilled 120, parmesan 20, bread_white 30, "
  "mayonnaise 25, olive_oil 10, lemon_juice 10, salt 2", 1.0, "porsiyon 300, tabak 300", "tavuklu sezar")
R("Rus salatası", "salad", "potato 300, carrot 150, peas 150, pickle 100, mayonnaise 150, yogurt 100, "
  "salt 5", 0.95, "porsiyon 150, yemek kaşığı 25", "amerikan salatası")
R("Yoğurtlu havuç salatası", "salad", "carrot 400, yogurt 300, garlic 5, olive_oil 20, salt 4", 0.9,
  "porsiyon 150, yemek kaşığı 25", "havuç tarator")
R("Pancar salatası", "salad", "beet 500, olive_oil 30, vinegar 20, garlic 5, salt 4", 0.95, "porsiyon 150")
R("Lahana salatası", "salad", "cabbage 400, carrot 100, olive_oil 30, lemon_juice 30, salt 5", 1.0, SAL)
R("Makarna salatası", "salad", "pasta 250, water 330, corn_canned 80, peas 80, pickle 80, mayonnaise 80, "
  "yogurt 100, salt 5", 0.97, "porsiyon 200, kase 200")
R("Söğüş", "salad", "tomato 200, cucumber 200, green_pepper 50", 1.0, "porsiyon 150, tabak 250",
  "domates salatalık")
R("Mercimek salatası", "salad", "lentil_green 250, water 400, onion 80, parsley 40, tomato 100, "
  "olive_oil 50, lemon_juice 30, salt 5", 0.95, "porsiyon 150, kase 200")
R("Kinoa salatası", "salad", "quinoa 200, water 300, tomato 150, cucumber 150, parsley 40, "
  "olive_oil 40, lemon_juice 30, salt 4", 0.95, "porsiyon 150, kase 200", "kinoa")

# ---------------------------------------------------------------- breakfast
R("Menemen", "breakfast", "tomato 400, green_pepper 150, egg 200, butter 20, sunflower_oil 20, salt 4",
  0.8, "porsiyon 250, tabak 250")
R("Sucuklu yumurta", "breakfast", "sucuk 100, egg 120, butter 10", 0.85, "porsiyon 200")
R("Haşlanmış yumurta", "breakfast", "egg 100", 1.0, "adet 50", "yumurta, haşlama yumurta")
R("Sahanda yumurta", "breakfast", "egg 100, butter 10, salt 1", 0.9, "adet 55, porsiyon 110",
  "yumurta tava, göz yumurta")
R("Omlet", "breakfast", "egg 150, milk 30, butter 10, salt 2", 0.9, "porsiyon 170", "sade omlet")
R("Peynirli omlet", "breakfast", "egg 150, milk 30, feta 40, butter 10, parsley 5", 0.9, "porsiyon 210")
R("Kaşarlı omlet", "breakfast", "egg 150, milk 30, gouda 40, butter 10", 0.9, "porsiyon 210")
R("Çılbır", "breakfast", "egg 100, yogurt 150, butter 15, pepper_flakes 2, garlic 2, salt 2", 1.0,
  "porsiyon 270")
R("Mıhlama", "breakfast", "cornmeal 100, butter 80, mozzarella 200, water 300, salt 3", 0.7,
  "porsiyon 200", "kuymak")
R("Pişi", "breakfast", "flour 500, water 300, yeast 10, salt 8, sunflower_oil 120", 0.85, "adet 60",
  "hamur kızartması")
R("Pankek", "breakfast", "flour 200, milk 300, egg 100, sugar 30, butter 20", 0.85, "adet 45", "pancake")
R("Krep", "breakfast", "flour 150, milk 400, egg 100, butter 20, salt 2", 0.9, "adet 60")
R("Yulaf lapası", "breakfast", "oats 50, milk 200, honey 10", 0.95, "kase 250", "yulaf, porridge")
R("Peynirli gözleme", "breakfast", "@gozleme_dough 150, feta 50, parsley 10, butter 10", 0.95,
  "adet 210", "gözleme")
R("Ispanaklı gözleme", "breakfast", "@gozleme_dough 150, spinach 60, onion 15, feta 25, butter 10", 0.9,
  "adet 235")
R("Patatesli gözleme", "breakfast", "@gozleme_dough 150, potato 80, onion 10, butter 12", 0.9, "adet 225")
R("Kıymalı gözleme", "breakfast", "@gozleme_dough 150, beef_ground_80 60, onion 15, butter 10", 0.9,
  "adet 210")
R("Su böreği", "breakfast", "flour 500, egg 200, water 400, butter 150, feta 300, parsley 30, salt 5",
  0.95, "dilim 150")
R("Sigara böreği", "breakfast", "phyllo 500, feta 300, parsley 30, egg 50, sunflower_oil 150", 0.9,
  "adet 30, porsiyon 150", "sigara")
R("Peynirli börek", "breakfast", "phyllo 500, feta 300, milk 200, egg 100, sunflower_oil 100, butter 50, "
  "parsley 20", 0.8, "dilim 150", "tepsi böreği, peynirli tepsi böreği")
R("Kıymalı börek", "breakfast", "phyllo 500, beef_ground_80 300, onion 150, milk 200, egg 100, "
  "sunflower_oil 100, butter 50, salt 6", 0.8, "dilim 150")
R("Patatesli börek", "breakfast", "phyllo 500, potato 500, onion 100, milk 200, egg 100, sunflower_oil 100, "
  "butter 50, salt 6", 0.8, "dilim 150")
R("Talaş böreği", "breakfast", "puff_pastry 400, beef_stew 300, onion 100, peas 80, carrot 80, butter 20, "
  "egg_yolk 20, salt 5", 0.8, "adet 120")
R("Siyah zeytin", "breakfast", "olive_black 100", 1.0, "adet 4, yemek kaşığı 15, porsiyon 30", "zeytin")
R("Yeşil zeytin", "breakfast", "olive_green 100", 1.0, "adet 4, yemek kaşığı 15, porsiyon 30")
R("Bal", "breakfast", "honey 100", 1.0, "tatlı kaşığı 7, yemek kaşığı 20")
R("Reçel", "breakfast", "jam 100", 1.0, "tatlı kaşığı 7, yemek kaşığı 20", "vişne reçeli, çilek reçeli")
R("Pekmez", "breakfast", "molasses 100", 1.0, "tatlı kaşığı 7, yemek kaşığı 20", "üzüm pekmezi, dut pekmezi",
  "molasses used as approximation for grape/mulberry pekmez")
R("Tahin pekmez", "breakfast", "tahini 30, molasses 40", 1.0, "yemek kaşığı 20, porsiyon 40")
R("Kaymak", "breakfast", "@kaymak 100", 1.0, "yemek kaşığı 15, porsiyon 30", "",
  "approximated as 60 % heavy cream + 40 % butter (~60 % fat)")
R("Bal kaymak", "breakfast", "honey 20, @kaymak 30", 1.0, "porsiyon 50")
R("Kakaolu fındık kreması", "breakfast", "hazelnut_spread 100", 1.0, "tatlı kaşığı 10, yemek kaşığı 20",
  "nutella, fındık kreması")

# ---------------------------------------------------------------- bread & bakery
R("Beyaz ekmek", "bread", "bread_white 100", 1.0, "dilim 28", "ekmek, francala, somun")
R("Tam buğday ekmeği", "bread", "bread_ww 100", 1.0, "dilim 30", "kepekli ekmek, tam buğday")
R("Çavdar ekmeği", "bread", "bread_rye 100", 1.0, "dilim 30", "çavdar")
R("Tost ekmeği", "bread", "bread_white 100", 1.0, "dilim 25")
R("Simit", "bread", "flour 1000, water 550, yeast 10, salt 15, molasses 100, sesame 150, sunflower_oil 20",
  0.82, "adet 110", "gevrek")
R("Peynirli poğaça", "bread", "flour 500, butter 100, sunflower_oil 60, yogurt 100, milk 100, egg 50, "
  "yeast 10, feta 150, salt 8", 0.85, "adet 70", "poğaça")
R("Açma", "bread", "flour 500, milk 200, butter 80, sunflower_oil 50, sugar 30, egg 50, yeast 15, "
  "water 50, salt 6", 0.85, "adet 80")
R("Lavaş", "bread", "@lavas 100", 1.0, "adet 70", "lavaş ekmeği")
R("Bazlama", "bread", "flour 500, yogurt 150, water 200, yeast 10, salt 8", 0.85, "adet 150")
R("Ramazan pidesi", "bread", "flour 1000, water 620, yeast 15, salt 15, sesame 15, egg_yolk 20", 0.85,
  "adet 350, dilim 50", "pide ekmeği")
R("Yufka", "bread", "phyllo 100", 1.0, "adet 110", "", "phyllo dough used as approximation for yufka")
R("Kruvasan", "bread", "croissant 100", 1.0, "adet 60", "croissant")
R("Pita ekmeği", "bread", "pita 100", 1.0, "adet 60", "pita")
R("Hamburger ekmeği", "bread", "bread_white 100", 1.0, "adet 60")
R("Mısır ekmeği", "bread", "cornmeal 400, flour 100, yogurt 200, egg 100, sunflower_oil 60, water 150, "
  "salt 6", 0.85, "dilim 60")
R("Galeta", "bread", "bread_white 100", 0.72, "adet 8", "", "toasted white bread, dried to 72 % of mass")

# ---------------------------------------------------------------- desserts
R("Fıstıklı baklava", "dessert", "phyllo 500, butter 250, pistachio 250, sugar 600, water 300", 0.85,
  "dilim 40, porsiyon 120", "baklava")
R("Cevizli baklava", "dessert", "phyllo 500, butter 250, walnut 250, sugar 600, water 300", 0.85,
  "dilim 40, porsiyon 120")
R("Künefe", "dessert", "phyllo 400, butter 150, mozzarella 300, sugar 400, water 250", 0.85,
  "porsiyon 150", "", "phyllo approximates kadayıf; mozzarella approximates künefe cheese")
R("Kadayıf tatlısı", "dessert", "phyllo 500, butter 200, walnut 150, sugar 600, water 400", 0.85,
  "dilim 80, porsiyon 120", "tel kadayıf")
R("Sütlaç", "dessert", "milk 1000, rice 80, sugar 150, cornstarch 30, water 300", 0.85, "kase 180",
  "fırın sütlaç")
R("Kazandibi", "dessert", "milk 1000, sugar 200, cornstarch 60, flour 30, butter 20", 0.9, "porsiyon 150")
R("Tavuk göğsü (tatlı)", "dessert", "milk 1000, chicken_breast 100, sugar 180, cornstarch 60, flour 30",
  0.9, "porsiyon 150", "tavuk göğsü tatlısı")
R("Muhallebi", "dessert", "milk 1000, sugar 150, cornstarch 50, flour 30", 0.92, "kase 180")
R("Keşkül", "dessert", "milk 1000, sugar 150, almond 80, cornstarch 50, coconut 20", 0.92, "kase 180")
R("Kakaolu puding", "dessert", "milk 1000, sugar 150, cocoa 40, cornstarch 60, butter 20", 0.92,
  "kase 180", "puding, supangle")
R("Revani", "dessert", "semolina 200, flour 100, sugar 600, water 400, egg 200, yogurt 150, "
  "sunflower_oil 50", 0.85, "dilim 90")
R("Şekerpare", "dessert", "flour 400, semolina 50, butter 200, powdered_sugar 120, egg 50, sugar 500, "
  "water 350", 0.85, "adet 45")
R("Tulumba tatlısı", "dessert", "flour 300, water 850, butter 50, egg 150, sunflower_oil 200, sugar 600",
  0.8, "adet 25, porsiyon 125", "tulumba")
R("Lokma tatlısı", "dessert", "flour 500, water 750, yeast 10, sunflower_oil 200, sugar 500", 0.8,
  "adet 15, porsiyon 120", "lokma")
R("Aşure", "dessert", "wheat 250, white_beans 100, chickpeas 100, sugar 400, apricot_dried 100, "
  "fig_dried 100, raisins 100, walnut 50, hazelnut 50, water 2500", 0.7, "kase 200")
R("Güllaç", "dessert", "cornstarch 60, flour 40, milk 1500, sugar 300, walnut 100", 0.95, "dilim 150")
R("İrmik helvası", "dessert", "semolina 500, butter 150, milk 500, water 300, sugar 400, almond 30", 0.85,
  "porsiyon 100, yemek kaşığı 30")
R("Un helvası", "dessert", "flour 500, butter 250, sugar 400, milk 300, water 300", 0.85, "porsiyon 100")
R("Tahin helvası", "dessert", "tahini 50, sugar 50", 1.0, "dilim 40, porsiyon 50", "helva",
  "approximated as 50 % tahini + 50 % sugar")
R("Kabak tatlısı", "dessert", "pumpkin 1000, sugar 300, walnut 50", 0.7, "porsiyon 150")
R("Ayva tatlısı", "dessert", "quince 800, sugar 300, water 300, @kaymak 50", 0.7, "adet 200")
R("Dondurma", "dessert", "ice_cream 100", 1.0, "adet 50, porsiyon 100", "maraş dondurması, külah dondurma")
R("Sütlü çikolata", "dessert", "milk_chocolate 100", 1.0, "dilim 7, adet 80", "çikolata")
R("Bitter çikolata", "dessert", "dark_chocolate 100", 1.0, "dilim 7, adet 80", "bitter")
R("Lokum", "dessert", "cornstarch 150, sugar 800, water 600", 0.65, "adet 15", "türk lokumu")
R("Yaş pasta", "dessert", "flour 200, sugar 200, egg 250, milk 300, heavy_cream 300, strawberry 200, "
  "cornstarch 30", 0.9, "dilim 120", "pasta, doğum günü pastası")
R("Profiterol", "dessert", "flour 120, butter 100, water 250, egg 200, milk 500, sugar 150, "
  "cornstarch 50, dark_chocolate 150, heavy_cream 100", 0.85, "porsiyon 150")
R("Magnolia", "dessert", "milk 500, sugar 100, cornstarch 40, heavy_cream 200, butter_cookies 100, "
  "strawberry 150", 0.95, "kase 180")
R("Trileçe", "dessert", "flour 150, egg 200, sugar 350, milk 750, heavy_cream 200", 0.9, "dilim 150")
R("Cheesecake", "dessert", "cream_cheese 600, sugar 200, egg 150, heavy_cream 150, butter_cookies 200, "
  "butter 80", 0.95, "dilim 120")
R("Brownie", "dessert", "dark_chocolate 200, butter 150, sugar 250, egg 150, flour 120, cocoa 30, "
  "walnut 50", 0.9, "dilim 60")
R("Sade kek", "dessert", "flour 300, sugar 250, egg 200, milk 200, sunflower_oil 120", 0.9, "dilim 60", "kek")
R("Kakaolu kek", "dessert", "flour 280, sugar 250, egg 200, milk 200, sunflower_oil 120, cocoa 30", 0.9,
  "dilim 60")
R("Kurabiye", "dessert", "flour 400, butter 200, powdered_sugar 120, egg 50", 0.92, "adet 20", "un kurabiyesi")
R("Bisküvi", "snack", "butter_cookies 100", 1.0, "adet 8, porsiyon 40", "petibör")
R("Kremalı bisküvi", "snack", "sandwich_cookies 100", 1.0, "adet 12, porsiyon 40")

# ---------------------------------------------------------------- drinks
R("Su", "drink", "water 100", 1.0, "bardak 200, su bardağı 200", "içme suyu")
R("Maden suyu", "drink", "club_soda 100", 1.0, "şişe 200", "soda")
R("Çay", "drink", "tea 100", 1.0, "çay bardağı 100", "demlik çay, siyah çay")
R("Şekerli çay", "drink", "tea 100, sugar 5", 1.0, "çay bardağı 105", "", "1 küp şeker (5 g) per glass")
R("Türk kahvesi", "drink", "espresso 100", 1.0, "fincan 70", "kahve, sade türk kahvesi",
  "espresso used as approximation for unfiltered Turkish coffee")
R("Orta şekerli Türk kahvesi", "drink", "espresso 70, sugar 5", 1.0, "fincan 75", "orta kahve")
R("Filtre kahve", "drink", "coffee 100", 1.0, "bardak 250", "americano")
R("Sütlü kahve (latte)", "drink", "espresso 60, milk 200", 1.0, "bardak 260", "latte")
R("Cappuccino", "drink", "espresso 60, milk 120", 1.0, "bardak 180")
R("Ayran", "drink", "yogurt 600, water 400, salt 5", 1.0, "bardak 200, şişe 300")
R("Kefir", "drink", "kefir 100", 1.0, "bardak 200")
R("Tam yağlı süt", "drink", "milk 100", 1.0, "su bardağı 200, bardak 200", "süt")
R("Yarım yağlı süt", "drink", "milk_2 100", 1.0, "su bardağı 200, bardak 200", "",
  "2 % milk used for Turkish 1.5 % yarım yağlı")
R("Light süt", "drink", "milk_1 100", 1.0, "su bardağı 200, bardak 200", "az yağlı süt")
R("Sıcak çikolata", "drink", "milk 200, cocoa 10, sugar 15", 1.0, "bardak 225")
R("Salep", "drink", "milk 1000, sugar 120, cornstarch 40, cinnamon 3", 0.95, "bardak 200, su bardağı 200",
  "sahlep", "cornstarch approximates salep powder")
R("Boza", "drink", "semolina 150, sugar 150, water 1000", 0.9, "bardak 200", "",
  "semolina approximates fermented millet/bulgur base")
R("Limonata", "drink", "lemon_juice 150, sugar 150, water 1000", 1.0, "bardak 200, su bardağı 200")
R("Portakal suyu", "drink", "orange_juice 100", 1.0, "bardak 200, su bardağı 200", "taze portakal suyu")
R("Elma suyu", "drink", "apple_juice 100", 1.0, "bardak 200, kutu 200")
R("Vişne suyu", "drink", "sour_cherry 400, sugar 120, water 600", 1.0, "bardak 200, kutu 200", "vişne nektarı")
R("Şalgam suyu", "drink", "carrot 50, beet 30, water 920, salt 15", 1.0, "bardak 200, şişe 300", "şalgam",
  "approximated with carrot + beet in brine")
R("Kola", "drink", "cola 100", 1.0, "kutu 330, bardak 200, şişe 500", "cola")
R("Gazoz", "drink", "club_soda 900, sugar 100", 1.0, "şişe 250, bardak 200")
R("Soğuk çay (şekerli)", "drink", "tea 930, sugar 70", 1.0, "şişe 330, kutu 330", "ice tea, buzlu çay")
R("Enerji içeceği", "drink", "energy_drink 100", 1.0, "kutu 250")
R("Soya sütü", "drink", "soymilk 100", 1.0, "bardak 200")
R("Badem sütü (şekersiz)", "drink", "almond_milk 100", 1.0, "bardak 200", "badem sütü")
R("Bira", "drink", "beer 100", 1.0, "şişe 500, kutu 330, bardak 400", "", "includes energy from alcohol")
R("Kırmızı şarap", "drink", "wine_red 100", 1.0, "kadeh 150", "şarap", "includes energy from alcohol")
R("Rakı", "drink", "spirits_90 100", 1.0, "kadeh 50", "",
  "90 proof distilled spirit used as approximation; includes energy from alcohol")
R("Milkshake", "drink", "milk 200, ice_cream 100, sugar 10", 1.0, "bardak 300")

# ---------------------------------------------------------------- fruits
R("Elma", "fruit", "apple 100", 1.0, "adet 180")
R("Muz", "fruit", "banana 100", 1.0, "adet 120")
R("Portakal", "fruit", "orange 100", 1.0, "adet 150")
R("Mandalina", "fruit", "mandarin 100", 1.0, "adet 80")
R("Üzüm", "fruit", "grapes 100", 1.0, "kase 150, avuç 60")
R("Karpuz", "fruit", "watermelon 100", 1.0, "dilim 300")
R("Kavun", "fruit", "melon 100", 1.0, "dilim 200", "", "honeydew used for kavun")
R("Çilek", "fruit", "strawberry 100", 1.0, "kase 150, adet 12")
R("Kiraz", "fruit", "cherry 100", 1.0, "kase 150, avuç 80")
R("Vişne", "fruit", "sour_cherry 100", 1.0, "kase 150, avuç 80")
R("Kayısı", "fruit", "apricot 100", 1.0, "adet 40")
R("Kuru kayısı", "fruit", "apricot_dried 100", 1.0, "adet 8, avuç 40")
R("Şeftali", "fruit", "peach 100", 1.0, "adet 150")
R("Armut", "fruit", "pear 100", 1.0, "adet 170")
R("Erik", "fruit", "plum 100", 1.0, "adet 30, avuç 90", "can erik")
R("İncir", "fruit", "fig 100", 1.0, "adet 50")
R("Kuru incir", "fruit", "fig_dried 100", 1.0, "adet 20")
R("Nar", "fruit", "pomegranate 100", 1.0, "kase 150, adet 250")
R("Kivi", "fruit", "kiwi 100", 1.0, "adet 75")
R("Ayva", "fruit", "quince 100", 1.0, "adet 250")
R("Hurma", "fruit", "dates 100", 1.0, "adet 24")
R("Kuru üzüm", "fruit", "raisins 100", 1.0, "yemek kaşığı 10, avuç 30")
R("Dut", "fruit", "mulberry 100", 1.0, "kase 140")
R("Greyfurt", "fruit", "grapefruit 100", 1.0, "adet 250")
R("Ananas", "fruit", "pineapple 100", 1.0, "dilim 80")
R("Trabzon hurması", "fruit", "persimmon 100", 1.0, "adet 170", "cennet hurması")
R("Limon", "fruit", "lemon 100", 1.0, "adet 60")

# ---------------------------------------------------------------- vegetables
R("Domates", "vegetable", "tomato 100", 1.0, "adet 150")
R("Salatalık", "vegetable", "cucumber 100", 1.0, "adet 130", "hıyar")
R("Yeşil biber", "vegetable", "green_pepper 100", 1.0, "adet 40", "dolmalık biber, çarliston")
R("Sivri biber", "vegetable", "hot_pepper 100", 1.0, "adet 10", "acı biber")
R("Kapya biber", "vegetable", "red_pepper 100", 1.0, "adet 150", "kırmızı biber")
R("Havuç", "vegetable", "carrot 100", 1.0, "adet 70")
R("Soğan", "vegetable", "onion 100", 1.0, "adet 110", "kuru soğan")
R("Taze soğan", "vegetable", "scallion 100", 1.0, "adet 15")
R("Marul", "vegetable", "lettuce_romaine 100", 1.0, "porsiyon 50")
R("Roka", "vegetable", "arugula 100", 1.0, "avuç 20")
R("Maydanoz", "vegetable", "parsley 100", 1.0, "avuç 15")
R("Turp", "vegetable", "radish 100", 1.0, "adet 10")
R("Mantar", "vegetable", "mushroom 100", 1.0, "porsiyon 100, adet 18")
R("Haşlanmış brokoli", "vegetable", "broccoli 100", 1.0, "porsiyon 150", "brokoli",
  "boiled with no added fat; mass assumed unchanged")
R("Haşlanmış karnabahar", "vegetable", "cauliflower 100", 1.0, "porsiyon 150", "karnabahar",
  "boiled with no added fat; mass assumed unchanged")
R("Haşlanmış patates", "vegetable", "potato 100", 1.0, "adet 150, porsiyon 150", "patates",
  "boiled in skin; mass assumed unchanged")
R("Haşlanmış mısır", "vegetable", "corn 100", 1.0, "adet 100", "mısır, közlenmiş mısır",
  "kernels only, edible part of one cob")
R("Konserve mısır", "vegetable", "corn_canned 100", 1.0, "yemek kaşığı 15, kase 150")
R("Turşu", "vegetable", "pickle 100", 1.0, "porsiyon 50, adet 30", "salatalık turşusu, karışık turşu")
R("Ispanak", "vegetable", "spinach 100", 1.0, "porsiyon 85")
R("Kabak", "vegetable", "zucchini 100", 1.0, "adet 200", "sakız kabağı")
R("Patlıcan", "vegetable", "eggplant 100", 1.0, "adet 250")
R("Közlenmiş biber", "vegetable", "red_pepper 100, olive_oil 3", 0.75, "adet 110", "köz biber")

# ---------------------------------------------------------------- dairy
R("Tam yağlı yoğurt", "dairy", "yogurt 100", 1.0, "kase 200, yemek kaşığı 20", "yoğurt")
R("Az yağlı yoğurt", "dairy", "yogurt_lowfat 100", 1.0, "kase 200, yemek kaşığı 20", "light yoğurt")
R("Süzme yoğurt", "dairy", "greek_yogurt 100", 1.0, "kase 150, yemek kaşığı 20", "yunan yoğurdu")
R("Beyaz peynir", "dairy", "feta 100", 1.0, "dilim 30, porsiyon 50", "peynir, ezine",
  "feta used for Turkish white cheese")
R("Kaşar peyniri", "dairy", "gouda 100", 1.0, "dilim 20, porsiyon 40", "kaşar", "gouda used for kaşar")
R("Tulum peyniri", "dairy", "feta 50, gouda 50", 1.0, "yemek kaşığı 15, porsiyon 40", "tulum",
  "approximated as 50 % feta + 50 % gouda")
R("Lor peyniri", "dairy", "ricotta_ps 100", 1.0, "yemek kaşığı 20, porsiyon 50", "lor",
  "part-skim ricotta used for lor")
R("Labne", "dairy", "cream_cheese_lf 100", 1.0, "yemek kaşığı 20", "", "low-fat cream cheese used for labne")
R("Dil peyniri", "dairy", "mozzarella 100", 1.0, "porsiyon 40", "", "mozzarella used for dil peyniri")
R("Cheddar peyniri", "dairy", "cheddar 100", 1.0, "dilim 20", "cheddar")
R("Mozzarella", "dairy", "mozzarella 100", 1.0, "porsiyon 40")
R("Parmesan", "dairy", "parmesan 100", 1.0, "yemek kaşığı 5")
R("Krem peynir", "dairy", "cream_cheese 100", 1.0, "yemek kaşığı 15", "krem peynir")
R("Cottage peyniri", "dairy", "cottage 100", 1.0, "yemek kaşığı 20, kase 200", "süzme peynir")
R("Krema", "dairy", "heavy_cream 100", 1.0, "yemek kaşığı 15", "sıvı krema")
R("Ekşi krema", "dairy", "sour_cream 100", 1.0, "yemek kaşığı 15")
R("Tereyağı", "dairy", "butter 100", 1.0, "tatlı kaşığı 5, yemek kaşığı 14")

# ---------------------------------------------------------------- meat, fish (plain)
R("Izgara tavuk göğsü", "meat", "@chicken_grilled 100", 1.0, "porsiyon 150, adet 120",
  "tavuk göğsü, tavuk ızgara")
R("Fırın tavuk but", "meat", "chicken_drumstick 1000, olive_oil 10, salt 8", 0.75, "adet 90, porsiyon 180",
  "tavuk but, baget")
R("Tavuk pirzola", "meat", "chicken_thigh 1000, olive_oil 15, salt 8", 0.72, "porsiyon 150", "tavuk incik")
R("Bütün fırın tavuk", "meat", "chicken_whole 1000, salt 10", 0.75, "porsiyon 200", "bütün tavuk")
R("Haşlanmış tavuk", "meat", "chicken_breast 1000", 0.75, "porsiyon 150", "haşlama tavuk")
R("Hindi eti (fırın)", "meat", "turkey_whole 1000, salt 8", 0.75, "porsiyon 150", "hindi")
R("Kavrulmuş kıyma", "meat", "beef_ground_80 1000, salt 8", 0.72, "yemek kaşığı 20, porsiyon 100", "kıyma")
R("Az yağlı kıyma (kavrulmuş)", "meat", "beef_ground_90 1000, salt 8", 0.72, "yemek kaşığı 20, porsiyon 100")
R("Kuzu pirzola", "meat", "lamb_rib 1000, salt 8", 0.7, "adet 50, porsiyon 200", "pirzola")
R("Biftek", "meat", "beef_round 1000, olive_oil 20, salt 8", 0.72, "porsiyon 200", "bonfile")
R("Antrikot", "meat", "beef_tbone 1000, salt 8", 0.72, "porsiyon 250", "steak")
R("Haşlanmış dana eti", "meat", "beef_stew 1000, salt 8", 0.65, "porsiyon 150", "haşlama")
R("Sucuk (tava)", "meat", "sucuk 100", 0.9, "dilim 8, porsiyon 50", "sucuk",
  "smoked beef sausage used as approximation for sucuk")
R("Pastırma", "meat", "pastirma 100", 1.0, "dilim 10, porsiyon 40", "", "cured dried beef used for pastırma")
R("Salam", "meat", "salami 100", 1.0, "dilim 10")
R("Sosis", "meat", "frankfurter 100", 1.0, "adet 40")
R("Hindi füme", "meat", "turkey_deli 100", 1.0, "dilim 10")
R("Izgara levrek", "meat", "sea_bass 1000, olive_oil 20, salt 8", 0.8, "porsiyon 200, adet 250", "levrek")
R("Izgara çipura", "meat", "sea_bass 1000, olive_oil 20, salt 8", 0.8, "porsiyon 200, adet 250", "çipura",
  "sea bass used as approximation for gilt-head bream")
R("Izgara somon", "meat", "salmon 1000, salt 8", 0.8, "porsiyon 200", "somon")
R("Izgara uskumru", "meat", "mackerel 1000, salt 8", 0.8, "porsiyon 200, adet 200", "uskumru")
R("Izgara alabalık", "meat", "trout 1000, salt 8", 0.8, "porsiyon 200, adet 200", "alabalık")
R("Izgara lüfer", "meat", "bluefish 1000, salt 8", 0.8, "porsiyon 200", "lüfer")
R("Ton balığı (yağlı konserve)", "meat", "tuna_oil 100", 1.0, "adet 80, yemek kaşığı 15", "ton balığı")
R("Ton balığı (su konserve)", "meat", "tuna_water 100", 1.0, "adet 80, yemek kaşığı 15")
R("Haşlanmış karides", "meat", "shrimp 100", 0.8, "porsiyon 150, adet 10", "karides")

# ---------------------------------------------------------------- legumes (plain)
R("Haşlanmış nohut", "legume", "chickpeas 100, water 140", 1.0, "kase 160, yemek kaşığı 15", "nohut haşlama")
R("Haşlanmış kuru fasulye", "legume", "white_beans 100, water 150", 1.0, "kase 180, yemek kaşığı 15")
R("Haşlanmış yeşil mercimek", "legume", "lentil_green 100, water 200", 1.0, "kase 200, yemek kaşığı 15",
  "haşlanmış mercimek")
R("Haşlanmış barbunya", "legume", "cranberry_beans 100, water 150", 1.0, "kase 180")
R("Haşlanmış bezelye", "legume", "peas 100", 0.95, "kase 160, yemek kaşığı 15", "bezelye")
R("Leblebi", "legume", "chickpeas 100", 0.93, "avuç 30, su bardağı 100", "sarı leblebi",
  "raw chickpeas dried to 93 % of mass (roasting), no added fat")
R("Taze bakla (haşlanmış)", "legume", "fava_fresh 100", 1.0, "porsiyon 150", "bakla")

# ---------------------------------------------------------------- grains (plain)
R("Pirinç (çiğ)", "grain", "rice 100", 1.0, "su bardağı 180, yemek kaşığı 15", "pirinç")
R("Haşlanmış pirinç (sade)", "grain", "rice 100, water 180", 1.0, "porsiyon 150, yemek kaşığı 25",
  "sade pirinç")
R("Haşlanmış esmer pirinç", "grain", "rice_brown 100, water 230", 1.0, "porsiyon 150", "esmer pirinç")
R("Bulgur (çiğ)", "grain", "bulgur 100", 1.0, "su bardağı 170, yemek kaşığı 15")
R("Makarna (çiğ)", "grain", "pasta 100", 1.0, "porsiyon 100")
R("Haşlanmış makarna (sade)", "grain", "pasta 100, water 130", 1.0, "porsiyon 200, tabak 250", "sade makarna")
R("Haşlanmış erişte", "grain", "egg_noodles 100, water 180", 1.0, "porsiyon 200")
R("Yulaf ezmesi", "grain", "oats 100", 1.0, "yemek kaşığı 10, su bardağı 80", "yulaf")
R("Kuskus (haşlanmış)", "grain", "couscous 100, water 150", 1.0, "porsiyon 150", "kuskus")
R("Kinoa (haşlanmış)", "grain", "quinoa 100, water 200", 1.0, "porsiyon 150")
R("Buğday unu", "grain", "flour 100", 1.0, "su bardağı 110, yemek kaşığı 10", "un")
R("İrmik", "grain", "semolina 100", 1.0, "su bardağı 160, yemek kaşığı 12")
R("Mısır unu", "grain", "cornmeal 100", 1.0, "su bardağı 140, yemek kaşığı 10")

# ---------------------------------------------------------------- snacks
R("Fındık", "snack", "hazelnut 100", 1.0, "avuç 30, adet 2")
R("Ceviz", "snack", "walnut 100", 1.0, "avuç 30, adet 5", "ceviz içi")
R("Badem", "snack", "almond 100", 1.0, "avuç 30, adet 1")
R("Antep fıstığı", "snack", "pistachio 100", 1.0, "avuç 30", "fıstık", "shelled weight")
R("Yer fıstığı", "snack", "peanut 100", 1.0, "avuç 30")
R("Kaju", "snack", "cashew 100", 1.0, "avuç 30")
R("Ay çekirdeği (iç)", "snack", "sunflower_seeds 100", 1.0, "avuç 30", "çekirdek",
  "kernel weight; shells are not eaten")
R("Kabak çekirdeği (iç)", "snack", "pumpkin_seeds 100", 1.0, "avuç 30", "", "kernel weight")
R("Karışık kuruyemiş", "snack", "hazelnut 25, almond 25, peanut 25, cashew 25", 1.0, "avuç 30", "kuruyemiş")
R("Cips", "snack", "potato_chips 100", 1.0, "porsiyon 30, avuç 15", "patates cipsi")
R("Patlamış mısır", "snack", "popcorn 100", 1.0, "kase 30", "", "air-popped, no fat")
R("Patlamış mısır (yağlı)", "snack", "popcorn 80, sunflower_oil 20, salt 1", 1.0, "kase 30, porsiyon 60",
  "sinema mısırı")
R("Kraker", "snack", "crackers 100", 1.0, "adet 3, avuç 20")
R("Kestane kebap", "snack", "chestnut 100", 1.0, "adet 10, porsiyon 100", "kestane")
R("Midye dolma", "snack", "mussel 300, rice 300, onion 200, olive_oil 80, water 450, raisins 20, "
  "salt 6", 0.85, "adet 25", "", "edible part (mussel + rice), shell excluded")

# ---------------------------------------------------------------- fast food
R("Et döner (porsiyon)", "fastfood", "@doner_beef 100", 1.0, "porsiyon 150", "döner, et döner")
R("Tavuk döner (porsiyon)", "fastfood", "@doner_chicken 100", 1.0, "porsiyon 150", "tavuk döner")
R("Et dürüm", "fastfood", "@lavas 90, @doner_beef 120, tomato 30, onion 20, lettuce_romaine 10", 1.0,
  "adet 270", "dürüm döner")
R("Tavuk dürüm", "fastfood", "@lavas 90, @doner_chicken 120, tomato 30, pickle 15, lettuce_romaine 10, "
  "mayonnaise 10", 1.0, "adet 275")
R("Ekmek arası döner", "fastfood", "bread_white 120, @doner_beef 100, tomato 30, onion 20", 1.0,
  "adet 270", "yarım ekmek döner")
R("Ekmek arası tavuk döner", "fastfood", "bread_white 120, @doner_chicken 100, tomato 30, pickle 15, "
  "mayonnaise 10", 1.0, "adet 275")
R("Çiğ köfte dürüm", "fastfood", "@cig_kofte 120, @lavas 60, lettuce_romaine 30, lemon_juice 5, "
  "molasses 5", 1.0, "adet 220")
R("Köfte ekmek", "fastfood", "bread_white 120, @kofte 100, tomato 30, onion 20", 1.0, "adet 270")
R("Balık ekmek", "fastfood", "bread_white 120, mackerel 120, onion 30, lettuce_romaine 20, lemon_juice 5",
  0.92, "adet 270")
R("Hamburger", "fastfood", "bread_white 70, @burger_patty 100, lettuce_iceberg 15, tomato 20, onion 10, "
  "ketchup 10, mayonnaise 10", 1.0, "adet 235", "burger")
R("Cheeseburger", "fastfood", "bread_white 70, @burger_patty 100, cheddar 20, lettuce_iceberg 15, "
  "tomato 20, onion 10, ketchup 10, mayonnaise 10", 1.0, "adet 255")
R("Tavuk burger", "fastfood", "bread_white 70, nuggets 100, lettuce_iceberg 15, mayonnaise 15", 1.0,
  "adet 200", "", "breaded chicken nuggets used for the fillet")
R("Islak hamburger", "fastfood", "bread_white 60, @burger_patty 50, tomato_sauce 30, butter 8, garlic 2",
  1.0, "adet 150", "ıslak burger")
R("Karışık pizza", "fastfood", "flour 300, water 180, yeast 5, olive_oil 15, tomato_sauce 100, "
  "mozzarella_lm 200, sucuk 60, salami 40, green_pepper 50, mushroom 50, olive_black 30", 0.85,
  "dilim 100, adet 800", "pizza")
R("Margarita pizza", "fastfood", "flour 300, water 180, yeast 5, olive_oil 15, tomato_sauce 120, "
  "mozzarella_lm 220", 0.85, "dilim 90, adet 700", "margherita")
R("Kaşarlı tost", "fastfood", "bread_white 70, gouda 40, butter 5", 0.95, "adet 110", "tost")
R("Karışık tost", "fastfood", "bread_white 70, gouda 30, sucuk 25, butter 5", 0.95, "adet 125")
R("Ayvalık tostu", "fastfood", "bread_white 150, gouda 50, sucuk 30, salami 30, tomato 30, pickle 20, "
  "ketchup 10, mayonnaise 10", 0.95, "adet 315")
R("Sosisli sandviç", "fastfood", "bread_white 80, frankfurter 60, ketchup 10, mustard 5, mayonnaise 10, "
  "pickle 10, corn_canned 10", 1.0, "adet 185", "sosisli")
R("Kumpir", "fastfood", "potato 400, butter 20, gouda 50, corn_canned 30, pickle 20, olive_black 15, "
  "mayonnaise 15, ketchup 15, salami 20", 0.85, "adet 500", "",
  "potato baked; typical toppings")
R("Tavuk nugget", "fastfood", "nuggets 100", 1.0, "adet 18, porsiyon 110", "nugget")

# ---------------------------------------------------------------- sauces, fats, condiments
R("Zeytinyağı", "sauce", "olive_oil 100", 1.0, "yemek kaşığı 14, tatlı kaşığı 5", "sızma zeytinyağı")
R("Ayçiçek yağı", "sauce", "sunflower_oil 100", 1.0, "yemek kaşığı 14, tatlı kaşığı 5", "sıvı yağ")
R("Margarin", "sauce", "margarine 100", 1.0, "tatlı kaşığı 5, yemek kaşığı 14")
R("Mayonez", "sauce", "mayonnaise 100", 1.0, "yemek kaşığı 14, tatlı kaşığı 5")
R("Ketçap", "sauce", "ketchup 100", 1.0, "yemek kaşığı 17, tatlı kaşığı 6")
R("Hardal", "sauce", "mustard 100", 1.0, "tatlı kaşığı 5")
R("Domates salçası", "sauce", "tomato_paste 100", 1.0, "yemek kaşığı 16, tatlı kaşığı 6", "salça")
R("Biber salçası", "sauce", "tomato_paste 70, red_pepper 30", 0.85, "yemek kaşığı 16, tatlı kaşığı 6", "",
  "approximated from tomato paste + red pepper")
R("Nar ekşisi", "sauce", "molasses 100", 1.0, "yemek kaşığı 20, tatlı kaşığı 7", "",
  "molasses used as approximation for pomegranate molasses")
R("Tahin", "sauce", "tahini 100", 1.0, "yemek kaşığı 15, tatlı kaşığı 5")
R("Sarımsaklı yoğurt", "sauce", "yogurt 200, garlic 5, salt 2", 1.0, "yemek kaşığı 20, kase 150")
R("Domates sosu", "sauce", "tomato 500, olive_oil 30, onion 50, garlic 5, salt 5", 0.7, "yemek kaşığı 20, kepçe 100")
R("Beşamel sos", "sauce", "@bechamel 100", 1.0, "yemek kaşığı 20, kepçe 100", "beşamel")
R("Şeker", "sauce", "sugar 100", 1.0, "adet 5, tatlı kaşığı 5, yemek kaşığı 13", "toz şeker, küp şeker")
R("Limon suyu", "sauce", "lemon_juice 100", 1.0, "yemek kaşığı 15")
R("Sirke", "sauce", "vinegar 100", 1.0, "yemek kaşığı 15", "elma sirkesi")
