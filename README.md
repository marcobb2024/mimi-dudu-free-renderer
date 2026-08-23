# Renderizador gratuito de Mimi y Dudu

Repositorio listo para GitHub Actions. Recibe un `repository_dispatch`, descarga un fondo vertical de Pexels y crea un MP4 de 15 segundos con FFmpeg.

## Uso

1. Suba todo el contenido de esta carpeta a la raíz de un repositorio público.
2. En Settings → Actions → General → Workflow permissions seleccione **Read and write permissions**.
3. Abra Actions y ejecute manualmente `Render diario Mimi y Dudu` para la prueba inicial.
4. Verifique `output/prueba-manual.mp4`.
5. Configure el workflow n8n incluido en el ZIP para enviar los trabajos diarios.

El flujo acepta los presets `cookie_heist`, `vacuum_chase`, `bag_surprise` y `dance_loop`. Si el fondo remoto falla, utiliza `assets/fallback_background.png`.

El audio incluido es una pista original de respaldo. La pista viral autorizada se adjunta dentro de Instagram durante la publicación y no se descarga ni se redistribuye.

## Solicitud de ejemplo

```json
{
  "event_type": "render-mimi-dudu",
  "client_payload": {
    "job_id": "20260823-prueba",
    "preset": "dance_loop",
    "motion_bpm": 108,
    "background_url": "",
    "hook_text": "NADIE TOQUE ESO",
    "twist_text": "DEMASIADO TARDE",
    "end_text": "OTRA VEZ"
  }
}
```

Los archivos terminados se guardan en `output/{job_id}.mp4`.

`motion_bpm` sincroniza el balanceo y el rebote de ambos personajes con el pulso estimado del audio elegido, sin deformar los PNG.

La selección creativa se ajusta semanalmente con métricas de los Reels propios de Facebook. El renderizador sigue produciendo un solo video original por día; no realiza cargas masivas.
