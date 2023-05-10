import numpy
from keras.datasets import mnist
from keras.models import Sequential
from keras.layers import Dense, Flatten
from keras.utils import np_utils

def baseline_model(num_pixels, num_classes):
    # Создаем модель с последовательной архитектурой (Sequential)
    model = Sequential()

    # Добавляем полносвязный слой (Dense) с количеством нейронов равным num_pixels,
    # указываем размер входных данных (input_dim) равный num_pixels,
    # инициализируем веса с помощью нормального распределения (kernel_initializer='normal')
    # и используем функцию активации ReLU
    model.add(Dense(num_pixels, input_dim=num_pixels, kernel_initializer='normal', activation='relu'))

    # Добавляем еще один полносвязный слой (Dense) с количеством нейронов равным num_classes (количество классов),
    # инициализируем веса с помощью нормального распределения (kernel_initializer='normal')
    # и используем функцию активации Softmax для преобразования выходных данных в вероятности принадлежности к каждому классу
    model.add(Dense(num_classes, kernel_initializer='normal', activation='softmax'))

    # Компилируем модель, указывая функцию потерь (loss) 'categorical_crossentropy' для многоклассовой классификации,
    # оптимизатор 'adam' для обновления весов модели в процессе обучения и метрику 'accuracy' для оценки производительности модели
    model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])

    # Возвращаем созданную модель
    return model

# Загрузить данные MNIST
(X_train, y_train), (X_test, y_test) = mnist.load_data()

# Преобразовать изображения размером 28x28 в плоский вектор длиной 784 для каждого изображения
num_pixels = X_train.shape[1] * X_train.shape[2]
X_train = X_train.reshape(X_train.shape[0], num_pixels).astype('float32')
X_test = X_test.reshape(X_test.shape[0], num_pixels).astype('float32')

# Нормализовать входные данные, переведя значения пикселей из диапазона 0-255 в диапазон 0-1
X_train = X_train / 255
X_test = X_test / 255

# Выполнить one-hot кодирование меток классов
y_train = np_utils.to_categorical(y_train)
y_test = np_utils.to_categorical(y_test)
num_classes = y_test.shape[1]

# Создать модель, используя функцию baseline_model
model = baseline_model(num_pixels, num_classes)

# Обучить модель, используя обучающий набор данных, и валидировать на тестовом наборе данных
model.fit(X_train, y_train, validation_data=(X_test, y_test), epochs=10)

# Оценить качество модели на тестовом наборе данных
scores = model.evaluate(X_test, y_test)
print("Baseline Error: %.2f%%" % (100-scores[1]*100))

# Сохранить обученную модель в файл "my_model1.h5" для дальнейшего использования
model.save("my_model1.h5")