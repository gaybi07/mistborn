# ActionForge por el puerto de depuración

La app de escritorio se abre con el puerto de depuración para manejarla desde la terminal:

```
"/c/Users/gabih/AppData/Local/Programs/actionforge-desktop/ActionForge.exe" --remote-debugging-port=9333 &
```

| Archivo | Para qué |
|---|---|
| `export.mjs` | Carga un clip con sus ajustes (Adjust) y lo baja en FBX, esqueleto de Mixamo, sin malla. **Lo normal.** |
| `upload.mjs` | Importa un FBX a ActionForge (pestaña Library, Yours). Sobre lo importado el Adjust no funciona. |
| `cdp.mjs` | Navaja suiza: `eval <archivo.js>`, `shot <png>`, `click x,y`, `key <tecla>`, `rot <hueso>,x,y,z` (rotación de un hueso en una capa, con el clip pausado en el cuadro 1). |
| `helpers.js`, `helpers2.js` | Funciones que se cargan en la página (`afDownload`, `afSlider`, `afFrame`). |

Los ajustes van en la dirección (`#a=...&clip=...`): `parámetro:k<fracción del clip>=<grados>|<fracción>=<grados>`.
Parámetros conocidos: `posture` (negativo endereza el torso), `armSpace` (Arms ↕), `armFwd` (Arms ↔), `headPitch`.
Las capas de rotación de huesos (`k=` en la dirección) quedan guardadas en la app aunque cambies de clip: no las uses
sin borrarlas después, porque se cuelan en las exportaciones siguientes.
