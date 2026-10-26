"""Test fixture: verbatim selected source functions; never import production settings."""

def validate_image(data, extension, max_seconds=3):
    """Inspect actual image bytes; client dimensions/duration are not evidence."""
    if extension == 'svg':
        try:
            source = data.decode('utf-8')
            if '<!' in source or re.search(r'(?i)(?:javascript:|https?:|data:|file:)', source):
                # The XML namespace is not an external resource.
                source = source.replace('http://www.w3.org/2000/svg', '').replace('http://www.w3.org/1999/xlink', '')
                if '<!' in source or re.search(r'(?i)(?:javascript:|https?:|data:|file:)', source):
                    raise ValueError('External resources are not allowed in emoji SVG')
            root = ET.fromstring(data)
            allowed = {'svg','g','path','rect','circle','ellipse','line','polyline','polygon','defs',
                       'linearGradient','radialGradient','stop','clipPath','mask','symbol','use','title','desc'}
            count = 0
            for element in root.iter():
                count += 1
                if count > 4096 or element.tag.split('}')[-1] not in allowed:
                    raise ValueError('Unsupported SVG content')
                for key, value in element.attrib.items():
                    name = key.split('}')[-1].lower()
                    if name.startswith('on') or (name == 'href' and not value.startswith('#')):
                        raise ValueError('Active SVG content is not allowed')
                    if 'url(' in value.lower() and not re.fullmatch(r'url\(\s*#[\w-]+\s*\)', value, re.I):
                        raise ValueError('External SVG resource')
            if root.tag.split('}')[-1] != 'svg': raise ValueError('Invalid SVG root')
            return 128, 128, False, None
        except (ET.ParseError, UnicodeError) as exc:
            raise ValueError('Invalid SVG image') from exc
    if extension in ('mp4','webm'):
        return None  # Existing video validation is preserved.
    from PIL import Image
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in {'PNG','WEBP','GIF'}:
                    raise ValueError('Unsupported image content')
                width, height = image.size
                if not width or not height or width*height > 2048*2048 or max(width,height)/min(width,height)>2:
                    raise ValueError('Emoji dimensions exceed supported limits')
                frames = getattr(image, 'n_frames', 1)
                if frames > 300: raise ValueError('Too many emoji frames')
                duration = 0
                for index in range(frames):
                    image.seek(index)
                    duration += image.info.get('duration', 0)
                animated = frames > 1
                if animated and not 0 < duration <= max_seconds*1000:
                    raise ValueError('Animated emoji duration exceeds limit')
                return width,height,animated,duration/1000 if animated else None
    except (OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise ValueError('Invalid or oversized emoji image') from exc
