const express = require('express');
const path = require('path');
const app = express();

// Ruta para servir la landing page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Ruta para servir el juego de snake
app.get('/snake', (req, res) => {
  res.sendFile(path.join(__dirname, 'index2.html'));
});

// Configuración del puerto
const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});