Faveo Helpdesk - Open Source Helpdesk & Support Ticketing
=========================================================

`Faveo Helpdesk`_ is an automated Helpdesk system to allow you to manage
customer support. It is built on the popular Laravel PHP framework. The
TurnKey appliance includes the open source Community Edition, but the Faveo
developers also offer a number of paid versions (hosted or self hosted).

To complete the experience, Faveo developers also provide free Community
Edition Android_ and iOS_ apps. Faveo Helpdesk provides usage and upgrade
documentation on their wiki_, including documentation of the powerful API_
and development of Faveo plugins_.

This TurnKey appliance also includes all the standard features in
`TurnKey Core`_, and on top of that:

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (MariaDB) (listening on port
  12322 - uses SSL).
- `Postfix`_ MTA (bound to localhost) to allow sending of email.
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**

-  Adminer: username **adminer**

-  Faveo Helpdesk: username is **admin**

.. _Faveo Helpdesk: https://www.faveohelpdesk.com/
.. _Android: https://play.google.com/store/apps/details?id=co.helpdesk.faveo
.. _iOS: https://apps.apple.com/in/app/faveo-helpdesk-community/id1185454914
.. _wiki: https://github.com/ladybirdweb/faveo-helpdesk/wiki
.. _API: https://github.com/ladybirdweb/faveo-helpdesk/wiki/API-Documentation
.. _plugins: https://github.com/ladybirdweb/faveo-helpdesk/wiki/Faveo-Plugin-creation-guide
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
.. _Postfix: https://www.postfix.org/
