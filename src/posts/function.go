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
	err := db.truncateTables(t)
	if err != nil {
		_, _ = io.WriteString(w, "Something went wrong, check the logs\n")
	} else {
		_, _ = io.WriteString(w, "Deleted the all posts\n")
	}

	db.closeClient()
}

func (db *db) truncateTables(tables []string) error {
	// Unset the foreign key checks.
	_, err := db.client.Exec("SET FOREIGN_KEY_CHECKS=0;")
	if err != nil {
		log.Printf("DB.Exec: unable to unset foreign key checks: %s", err)
		return err
	}

	// Truncate the specified tables.
	for _, v := range tables {
		_, err = db.client.Exec(fmt.Sprintf("TRUNCATE TABLE %s;", v))
		if err != nil {
			log.Printf("DB.Exec: unable to truncate table: %s", err)
			return err
		}
	}

	// Set the foreign key checks.
	_, err = db.client.Exec("SET FOREIGN_KEY_CHECKS=1;")
	if err != nil {
		log.Fatalf("DB.Exec: unable to set foreign key checks: %s", err)
		return err
	}

	log.Printf("Deleted all the posts\n")
	return nil
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
		db.client, err = initTCPConnectionPool()
		if err != nil {
			log.Fatalf("initTCPConnectionPool: unable to connect: %v", err)
		}
	} else {
		db.client, err = initSocketConnectionPool()
		if err != nil {
			log.Fatalf("initSocketConnectionPool: unable to connect: %v", err)
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
		log.Fatalf("Warning: %s environment variable not set.\n", k)
	}
	return v
}

func initSocketConnectionPool() (*sql.DB, error) {
	var (
		user = checkVar("DB_USERNAME")
		pwd  = checkVar("DB_PASSWORD")
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

	configureConnectionPool(pool)
	return pool, nil
}

func initTCPConnectionPool() (*sql.DB, error) {
	var (
		user = checkVar("DB_USERNAME")
		pwd  = checkVar("DB_PASSWORD")
		host = checkVar("DB_HOSTNAME")
		port = checkVar("DB_PORT")
		dbn  = checkVar("DB_NAME")
	)

	uri := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true", user, pwd, host, port, dbn)
	pool, err := sql.Open("mysql", uri)
	if err != nil {
		return nil, fmt.Errorf("sql.Open: %v", err)
	}

	configureConnectionPool(pool)
	return pool, nil
}

func configureConnectionPool(pool *sql.DB) {
	pool.SetMaxIdleConns(5)
	pool.SetMaxOpenConns(7)
	pool.SetConnMaxLifetime(1800 * time.Second)
}
