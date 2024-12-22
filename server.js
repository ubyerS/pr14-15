const express = require('express');
const { Pool } = require('pg');
const app = express();
const port = 8080;
const cors = require('cors');
const { v4: uuidv4, validate } = require('uuid');
app.use(cors({ origin: '*' }));
app.use(express.json());

const { Client } = require('pg');
const client = new Client();



const pool = new Pool({
  connectionString: 'postgresql://postgres:12345qweewq--12@db.lccmlzysstrvkmnlboup.supabase.co:5432/postgres',
  ssl: {
    rejectUnauthorized: false,
  },
});



app.get('/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM public.product'); 
    res.status(200).json(result.rows); 
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при получении данных из базы данных' });
  }
});




app.post('/products', async (req, res) => {
  const { name, description, price, stock, image_url } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO product (name, description, price, stock, image_url) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, description, price, stock, image_url]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при добавлении продукта' });
  }
});

app.put('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { name, description, price, stock, image_url } = req.body;
  try {
    const result = await pool.query(
      'UPDATE product SET name = $1, description = $2, price = $3, stock = $4, image_url = $5 WHERE product_id = $6 RETURNING *',
      [name, description, price, stock, image_url, id]
    );
    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при обновлении продукта' });
  }
});

app.put('/products/update/:id', async (req, res) => {
  const productId = parseInt(req.params.id);
  const { name, description, price, stock, image_url } = req.body;

  try {
    const result = await pool.query(
      'UPDATE product SET name = $1, description = $2, price = $3, stock = $4, image_url = $5 WHERE product_id = $6 RETURNING *',
      [name, description, price, stock, image_url, productId]
    );

    if (result.rows.length > 0) {
      res.status(200).json(result.rows[0]);
    } else {
      res.status(404).send('Product not found');
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при обновлении продукта' });
  }
});


app.delete('/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM product WHERE product_id = $1', [id]);
    res.status(204).send();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при удалении продукта' });
  }
});
app.get('/cart/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    const result = await pool.query(
      `SELECT c.cart_id, p.product_id, p.name, p.description, p.price, c.quantity, p.image_url, c.added_at
       FROM cart c
       JOIN product p ON c.product_id = p.product_id
       WHERE c.user_id = $1`,
      [user_id]
    );

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Ошибка при получении корзины:', error);
    res.status(500).json({ error: 'Ошибка при получении корзины' });
  }
});


app.post('/cart', async (req, res) => {
  const { user_id, product_id, quantity } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO cart (user_id, product_id, quantity) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (user_id, product_id) 
       DO UPDATE SET quantity = cart.quantity + EXCLUDED.quantity 
       RETURNING *`,
      [user_id, product_id, quantity]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Ошибка при добавлении товара в корзину:', error);
    res.status(500).json({ error: 'Ошибка при добавлении товара в корзину' });
  }
});

app.put('/cart', async (req, res) => {
  const { user_id, product_id, quantity } = req.body;

  try {
    const result = await pool.query(
      `UPDATE cart 
       SET quantity = $1 
       WHERE user_id = $2 AND product_id = $3 
       RETURNING *`,
      [quantity, user_id, product_id]
    );

    if (result.rows.length === 0) {
      res.status(404).json({ error: 'Товар не найден в корзине' });
    } else {
      res.status(200).json(result.rows[0]);
    }
  } catch (error) {
    console.error('Ошибка при обновлении количества товара:', error);
    res.status(500).json({ error: 'Ошибка при обновлении количества товара' });
  }
});

app.delete('/cart', async (req, res) => {
  const { user_id, product_id } = req.body;

  try {
    const result = await pool.query(
      `DELETE FROM cart 
       WHERE user_id = $1 AND product_id = $2`,
      [user_id, product_id]
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'Товар не найден в корзине' });
    } else {
      res.status(200).json({ message: 'Товар удален из корзины' });
    }
  } catch (error) {
    console.error('Ошибка при удалении товара из корзины:', error);
    res.status(500).json({ error: 'Ошибка при удалении товара из корзины' });
  }
});


app.delete('/cart/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    await pool.query(
      `DELETE FROM cart 
       WHERE user_id = $1`,
      [user_id]
    );

    res.status(200).json({ message: 'Корзина очищена' });
  } catch (error) {
    console.error('Ошибка при очистке корзины:', error);
    res.status(500).json({ error: 'Ошибка при очистке корзины' });
  }
});



app.get('/favorites/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    const result = await pool.query(
      `SELECT f.favorite_id, p.product_id, p.name, p.description, p.price, p.image_url, f.added_at
       FROM favorites f
       JOIN product p ON f.product_id = p.product_id
       WHERE f.user_id = $1`,
      [user_id]
    );

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Ошибка при получении избранных товаров:', error);
    res.status(500).json({ error: 'Ошибка при получении избранных товаров' });
  }
});


app.post('/favorites', async (req, res) => {
  const { user_id, product_id } = req.body;

  try {
    const result = await pool.query(
      'SELECT * FROM favorites WHERE user_id = $1 AND product_id = $2',
      [user_id, product_id]
    );

    if (result.rows.length === 0) {
      await pool.query(
        'INSERT INTO favorites (user_id, product_id) VALUES ($1, $2)',
        [user_id, product_id]
      );
      res.status(201).json({ message: 'Товар добавлен в избранное' });
    } else {
      res.status(400).json({ error: 'Товар уже в избранном' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка при добавлении товара в избранное' });
  }
});

app.post('/orders', async (req, res) => {
  const { user_id, total, status = 'Pending' } = req.body;

  try {
    const result = await pool.query(
      'SELECT * FROM orders WHERE user_id::uuid = $1::uuid',
      [user_id]
    );    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Ошибка при создании заказа:', error);
    res.status(500).json({ error: 'Ошибка при создании заказа' });
  }
});

app.get('/order_products/:order_id', async (req, res) => {
  const { order_id } = req.params;

  if (!validate(order_id)) {
    return res.status(400).json({ error: 'Неверный формат order_id' });
  }

  try {
    const result = await pool.query(
      `SELECT op.order_id, 
              op.product_id, 
              p.name, 
              p.description, 
              p.price, 
              op.quantity
       FROM order_products op
       JOIN product p ON op.product_id = p.product_id
       WHERE op.order_id = $1`,
      [order_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Продукты для этого заказа не найдены' });
    }

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Ошибка при получении продуктов заказа:', error);
    res.status(500).json({ error: 'Ошибка при получении продуктов заказа' });
  }
});



app.get('/orders/:user_id', async (req, res) => {
  const { user_id } = req.params;
  
  if (!validate(user_id)) {
    return res.status(400).json({ error: 'Неверный формат user_id' });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM orders WHERE user_id::uuid = $1::uuid',
      [user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Заказы не найдены' });
    }

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Ошибка при получении заказов:', error);
    res.status(500).json({ error: 'Ошибка при получении заказов' });
  }
});






app.get('/orders/total/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    const result = await pool.query(
      `SELECT SUM(total) as total FROM orders WHERE user_id::uuid = $1::uuid`,
      [user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Заказы не найдены' });
    }

    res.status(200).json({ total: result.rows[0].total });
  } catch (error) {
    console.error('Ошибка при получении суммы заказа:', error);
    res.status(500).json({ error: 'Ошибка при получении суммы заказа' });
  }
});


app.post('/orders/:order_id/products', async (req, res) => {
  const { order_id } = req.params;
  const { product_id, quantity } = req.body;

  if (!product_id || !quantity) {
    return res.status(400).json({ error: 'Не указаны необходимые данные (product_id, quantity)' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO order_products (order_id, product_id, quantity) VALUES ($1, $2, $3) RETURNING *',
      [order_id, product_id, quantity]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Ошибка при добавлении продукта в заказ:', error);
    res.status(500).json({ error: 'Ошибка при добавлении продукта в заказ' });
  }
});

app.get('/orders/:order_id', async (req, res) => {
  const { order_id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM orders WHERE order_id = $1',
      [order_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Заказ не найден' });
    }

    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Ошибка при получении информации о заказе:', error);
    res.status(500).json({ error: 'Ошибка при получении информации о заказе' });
  }
});




app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});