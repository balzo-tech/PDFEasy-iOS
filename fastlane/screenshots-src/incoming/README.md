# Le immagini fatte a mano

Qui dentro non ci mette le mani nessuno script. `out/` invece la riscrive
`export.sh` a ogni giro: le immagini fatte fuori dal simulatore vanno messe qui,
non lì.

    incoming/<lingua>/iphone/   1284x2778   (o 1242x2688)
    incoming/<lingua>/ipad/     2048x2732   (o 2732x2048)

I file si ordinano per nome: 1.png, 2.png, … 6.png, nell'ordine in cui devono
comparire sulla scheda.

Poi:

    ./fit-sizes.sh incoming/it/iphone                        # porta alla misura
    TARGET_W=2048 TARGET_H=2732 ./fit-sizes.sh incoming/it/ipad
    ./place-shots.sh
