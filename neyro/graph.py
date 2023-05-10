import tkinter as tk
from PIL import Image, ImageDraw
from tensorflow.keras.models import load_model
import numpy as np

# Загрузка обученной модели
model = load_model('my_model.h5')

# Функция predict_digit принимает изображение img и изменяет его размер до 28x28 пикселей для соответствия с моделью
# Преобразуем изображение в массив NumPy, изменяем его форму и нормализуем значения пикселей, деля их на 255.
# Также для точности переводим изображение в градиент серого

def predict_digit(img):
    img = img.resize((28, 28))
    img = img.convert('L')

    img = np.array(img)
    img = np.reshape(img, (1,784))
    img = img / 255

    where_0 = np.where(img == 0)
    where_1 = np.where(img == 1)

    img[where_0] = 1
    img[where_1] = 0


    # Получаем предсказание модели для изображения, выводим результат на экран и возвращаем индекс
    # максимального значения в массиве предсказаний (это и есть распознанная цифра).
    prediction = model.predict(img)
    return np.argmax(prediction)

# Функция on_paint обрабатывает событие рисования на холсте (canvas) приложения.
# Она создает круги на холсте и линии на изображении image1 в соответствии с перемещением курсора мыши.
def on_paint(event):
    x1, y1 = (event.x - 5), (event.y - 5)
    x2, y2 = (event.x + 5), (event.y + 5)
    canvas.create_oval(x1, y1, x2, y2, fill='black', width=5)
    draw.line([x1, y1, x2, y2], fill='black', width=5)

# Функция clear_canvas очищает холст и изображение image1, заполняя их белым цветом.
def clear_canvas():
    canvas.delete('all')
    draw.rectangle([(0, 0), (280, 280)], fill='white')

# Функция recognize_digit вызывает функцию predict_digit для копии изображения image1 и выводит распознанную цифру в виджете result_label.
def recognize_digit():
    img = image1.copy()
    digit = predict_digit(img)
    result_var.set(f"Распознанная цифра: {digit}")

window = tk.Tk()
window.title("Распознавание цифр")

# Создаём форму приложения

canvas = tk.Canvas(window, width=280, height=280, bg='white')
canvas.grid(row=0, column=0, pady=2, sticky='W', columnspan=2)

image1 = Image.new('RGB', (280, 280), 'white')

draw = ImageDraw.Draw(image1)

canvas.bind('<B1-Motion>', on_paint)

result_var = tk.StringVar()
result_label = tk.Label(window, textvariable=result_var, font=("Arial", 14))
result_label.grid(row=0, column=2, padx=2)

clear_button = tk.Button(window, text="Очистить", command=clear_canvas)
clear_button.grid(row=1, column=0, pady=2)

recognize_button = tk.Button(window, text="Распознать", command=recognize_digit)
recognize_button.grid(row=1, column=1, pady=2)

exit_button = tk.Button(window, text="Выход", command=window.quit)
exit_button.grid(row=1, column=2, pady=2)

window.mainloop()