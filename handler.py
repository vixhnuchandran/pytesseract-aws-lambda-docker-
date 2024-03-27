import json
import pytesseract
import base64
from io import BytesIO
from PIL import Image
import os

 
def ocr(event, context):
    
    request_body = json.loads(event['body'])
    image = base64_to_image(request_body['image'])
    result = process_image(image)
    
    text = construct_text(result)
    bboxes = [{'text': bbox['text'], 'data': {'confidence': bbox['confidence'], 'bbox': bbox['bbox']}} for bbox in result]
    
    response_body = {
        "text": text,
        "bboxes": bboxes 
    }


    response = {
        "statusCode": 200,
        "body": json.dumps(response_body)
    }

    return response

def construct_text(result):
    text = ""

    for bbox in result:
        text += bbox['text'] + " "

    return text.strip()

def base64_to_image(base64_str):
    format, imgstr =  base64_str.split(';base64,')
    ext = format.split('/')[-1]
    
    image_bytes = base64.b64decode(imgstr)
    
    image = Image.open(BytesIO(image_bytes))
    return image
    
def process_image(image):
    
    gray_img = image.convert('L')
    
    data = pytesseract.image_to_data(gray_img, output_type=pytesseract.Output.DICT)
    
    texts = [text for text in data['text'] if text.strip()]
    
    confidences = data['conf']
    lefts = data['left']
    tops = data['top']
    widths = data['width']
    heights = data['height']
    
    result = []
    for text, conf, left, top, width, height in zip(texts, confidences, lefts, tops, widths, heights):
        bbox = {
         'text': text,
         'confidence': conf,
         'bbox': {
             'left': left,
             'top': top,
             'right': left + width,
             'bottom': top + height
            }
        }
        result.append(bbox)
    return result


    
    