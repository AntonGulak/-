import numpy as np
from keras.layers import Dense, Flatten
from keras.models import Sequential
from keras.utils import to_categorical
from keras.datasets import mnist

# Загружаем данные рукописных цифр MNIST и разделяем их на обучающую и тестовую выборку.
(X_train, y_train), (X_test, y_test) = mnist.load_data()

# Преобразуем метки обучающей и тестовой выборки (y_train и y_test) в формат one-hot encoding.
# Это представление меток позволяет нейронной сети лучше обучаться на задачах многоклассовой классификации.
temp = []
for i in range(len(y_train)):
    temp.append(to_categorical(y_train[i], num_classes=10))
y_train = np.array(temp)

temp = []
for i in range(len(y_test)):
    temp.append(to_categorical(y_test[i], num_classes=10))
y_test = np.array(temp)


# Создаем последовательную модель нейронной сети (Sequential). Входной слой Flatten преобразует двумерные изображения 28x28 пикселей
# в одномерный массив. Следующий слой – это полносвязный слой с 5 нейронами и функцией активации sigmoid.
# Выходной слой – это полносвязный слой с 10 нейронами (по количеству классов) и функцией активации softmax.
model = Sequential()
model.add(Flatten(input_shape=(28,28)))
model.add(Dense(5, activation='sigmoid'))
model.add(Dense(10, activation='softmax'))

# Компилируем модель, указывая функцию потерь (categorical_crossentropy), оптимизатор (adam) и метрику для оценки качества обучения (точность, acc).
model.compile(loss='categorical_crossentropy',
              optimizer='adam',
              metrics=['acc'])

#Обучаем модель на обучающих данных, указывая количество эпох (5) и данные для валидации (тестовая выборка).
model.fit(X_train, y_train, epochs=10,
          validation_data=(X_test,y_test))


#Сохраняем обученную модель в файл "my_model.h5" для дальнейшего использования.
model.save("my_model.h5")