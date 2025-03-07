# SimpleBlog: No-nonsense, self-hostable blogging platform.

If you really care about your blogging data, and you're a minimalist one, this platform is for you.

## Deployment

All you need is Docker installed on your server, and access to server via SSH.


First, create a docker volume to store the database.

```bash
docker volume create simpleblog
```

Then, run this command to run the blogging platform. Make sure to **change the APP_USERNAME and APP_PASSWORD** before running the command.

```bash
docker run -v simpleblog:/app/storage -p 80:3000 -e RACK_ENV=production -e APP_USERNAME=your-username -e APP_PASSWORD=your-password -d adiprnm/simpleblog:latest
```

Now the blogging platform should be accessible from your domain/public IP address.

To access the admin page, you can visit `<your-domain/ip>/admin` in your browser. Enter your username and password as defined in the `APP_USERNAME` and `APP_PASSWORD` environment variable.

That's all. Happy blogging!

## Roadmap

This project's roadmap can be accessed at my blog: [https://blog.adipurnm.my.id/roadmap](https://blog.adipurnm.my.id/roadmap).

Stay tuned for more interesting features to come!
