package posts

import (
	"database/sql"
	"fmt"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	_ "github.com/go-sql-driver/mysql"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

type db struct {
	client *sql.DB
}

func init() {
	functions.HTTP("DeleteAll", DeleteAll)
}

func DeleteAll(w http.ResponseWriter, _ *http.Request) {
	// Set the tables related to the posts.
	t := []string{"posts", "posts_meta", "posts_authors", "posts_tags"}

	db, _ := newClient()

	// Truncate the post related tables.
	db.truncateTables(t)

	_, _ = io.WriteString(w, "Deleted all the posts\n")
	db.closeClient()
}

func (db *db) truncateTables(tables []string) {
	// Unset the foreign key checks.
	_, err := db.client.Exec("SET FOREIGN_KEY_CHECKS=0")
	if err != nil {
		log.Fatalf("DB.Exec: unable to unset foreign key checks: %s", err)
	}

	// Truncate the specified tables.
	for _, v := range tables {
		_, err = db.client.Exec(fmt.Sprintf("TRUNCATE TABLE %s", v))
		if err != nil {
			log.Fatalf("DB.Exec: unable to truncate table: %s", err)
		}
	}

	// Set the foreign key checks.
	_, err = db.client.Exec("SET FOREIGN_KEY_CHECKS=1")
	if err != nil {
		log.Fatalf("DB.Exec: unable to set foreign key checks: %s", err)
	}

	log.Printf("Deleted all the posts\n")
}

func newClient() (*db, error) {
	db := &db{}
	db.connectClient()
	return db, nil
}

func (db *db) connectClient() {
	log.Printf("Connecting to the database...\n")
	var err error

	// Connect using TCP sockets if DB_HOSTNAME is set; otherwise, connect using Unix sockets.
	if os.Getenv("DB_HOSTNAME") != "" {
		db.client, err = initTCPConnection()
		if err != nil {
			log.Fatalf("initTCPConnection: unable to connect: %v", err)
		}
	} else {
		db.client, err = initSocketConnection()
		if err != nil {
			if err != nil {
				log.Fatalf("initSocketConnection: unable to connect: %v", err)
			}
		}
	}
}

func (db *db) closeClient() {
	_ = db.client.Close()
	log.Printf("Closed the connection to the database\n")
}

func checkVar(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("Warning: %s environment variable not set\n", k)
	}
	return v
}

func initSocketConnection() (*sql.DB, error) {
	var (
		user = checkVar("DB_USERNAME")
		pwd  = os.Getenv("DB_PASSWORD")
		conn = checkVar("INSTANCE_CONNECTION_NAME")
		dbn  = checkVar("DB_NAME")
	)

	soc, set := os.LookupEnv("DB_SOCKET_DIR")
	if !set {
		soc = "/cloudsql"
	}

	uri := fmt.Sprintf("%s:%s@unix(/%s/%s)/%s?parseTime=true", user, pwd, soc, conn, dbn)
	pool, err := sql.Open("mysql", uri)
	if err != nil {
		return nil, fmt.Errorf("sql.Open: %v", err)
	}

	configurePool(pool)
	return pool, nil
}

func initTCPConnection() (*sql.DB, error) {
	var (
		user = checkVar("DB_USERNAME")
		pwd  = os.Getenv("DB_PASSWORD")
		host = checkVar("DB_HOSTNAME")
		port = checkVar("DB_PORT")
		dbn  = checkVar("DB_NAME")
	)

	uri := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true", user, pwd, host, port, dbn)
	pool, err := sql.Open("mysql", uri)
	if err != nil {
		return nil, fmt.Errorf("sql.Open: %v", err)
	}

	configurePool(pool)
	return pool, nil
}

func configurePool(pool *sql.DB) {
	pool.SetMaxIdleConns(2)
	pool.SetMaxOpenConns(0)
	pool.SetConnMaxLifetime(1800 * time.Second)
}
